package com.example.messaging_service.service;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TreeMap;
import java.util.regex.Pattern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.client.RestClient;

import com.example.messaging_service.dto.MessageType;
import com.example.messaging_service.dto.ProviderConfig;
import com.example.messaging_service.dto.ProviderResponse;
import com.example.messaging_service.exception.ErrorCode;
import com.example.messaging_service.exception.InvalidProviderException;
import com.example.messaging_service.exception.MessagingException;
import com.example.messaging_service.provider.MessageProvider;
import com.example.messaging_service.provider.extensible.ExtensibleProvider;
import com.example.messaging_service.provider.store.ProviderStore;

/**
 * Owns every provider. Providers are registered, updated and unregistered through the API and kept
 * in db.json; each one becomes a {@link ExtensibleProvider}. A request names its provider, which
 * must be registered, enabled and on the request's channel.
 * <p>
 * Every change is checked, saved to db.json, and only then made live by swapping in a new map, so
 * requests read it without a lock.
 */
@Component
public class ProviderRegistry {

	private static final Logger log = LoggerFactory.getLogger(ProviderRegistry.class);

	static final String MASK = "****";

	private static final Pattern VALID_ID = Pattern.compile("[A-Z0-9_-]+");

	private final RestClient.Builder builder;

	private final ProviderStore store;

	// Registered providers by id, replaced as a whole on every change.
	private volatile Map<String, Stored> providers;

	/**
	 * Loads db.json. A broken entry stops the app, so a request never fails because of it.
	 *
	 * @param builder Spring Boot's builder with the shared HTTP client; each provider gets a copy
	 * @param store where registered providers are kept (db.json)
	 */
	public ProviderRegistry(RestClient.Builder builder, ProviderStore store) {
		this.builder = builder;
		this.store = store;
		List<String> problems = new ArrayList<>();
		Map<String, Stored> loaded = new TreeMap<>();
		for (ProviderConfig config : store.load()) {
			String id = normalizeId(config.id());
			if (id == null || !VALID_ID.matcher(id).matches()) {
				problems.add("%s has a provider with id '%s'; ids may only use letters, digits, '_' and '-'"
					.formatted(store.location(), config.id()));
				continue;
			}
			if (loaded.containsKey(id)) {
				problems.add("%s has provider %s twice".formatted(store.location(), id));
				continue;
			}
			try {
				Stored stored = new Stored(config.withId(id), build(config.withId(id)));
				if (stored.config().enabled() && !stored.provider().isConfigured()) {
					problems.add("%s is enabled in %s but its credentials are missing".formatted(id, store.location()));
				}
				loaded.put(id, stored);
			}
			catch (IllegalStateException e) {
				problems.add("In %s: %s".formatted(store.location(), e.getMessage().replace("\n - ", "\n     - ")));
			}
		}
		if (!problems.isEmpty()) {
			throw new IllegalStateException("Invalid providers:\n - " + String.join("\n - ", problems));
		}
		this.providers = Collections.unmodifiableMap(loaded);
		log.info("{} provider(s) loaded from {}", loaded.size(), store.location());
	}

	/**
	 * The provider for one request. Throws MessagingException when it is not registered, is on
	 * another channel, or is disabled.
	 */
	public MessageProvider resolve(String requested, MessageType type) {
		Map<String, Stored> current = providers;
		String id = normalizeId(requested);
		Stored stored = (id == null) ? null : current.get(id);
		if (stored == null) {
			String known = current.isEmpty() ? "No providers are registered."
					: "Registered providers: %s.".formatted(String.join(", ", current.keySet()));
			throw new MessagingException(ErrorCode.UNSUPPORTED_PROVIDER, null,
					"Provider '%s' is not registered. %s".formatted(requested, known));
		}
		if (stored.config().channel() != type) {
			throw new MessagingException(ErrorCode.UNSUPPORTED_MESSAGE_TYPE, id,
					"Provider '%s' does not support %s.".formatted(id, type));
		}
		if (!stored.config().enabled()) {
			throw new MessagingException(ErrorCode.PROVIDER_UNAVAILABLE, id,
					"Provider '%s' is disabled.".formatted(id));
		}
		return stored.provider();
	}

	/** Every registered provider, sorted by id, secrets masked. */
	public List<ProviderResponse> providers() {
		return providers.values().stream().map(stored -> response(stored.config())).toList();
	}

	/** One registered provider, secrets masked. 404 when there is none. */
	public ProviderResponse provider(String id) {
		return response(requireStored(normalizeId(id)).config());
	}

	/** Adds a provider to db.json and makes it usable right away. */
	public synchronized ProviderResponse register(ProviderConfig config) {
		String id = requireValidId(config.id());
		if (providers.containsKey(id)) {
			throw new MessagingException(ErrorCode.PROVIDER_ALREADY_EXISTS, id,
					"Provider '%s' already exists.".formatted(id));
		}
		ProviderResponse saved = apply(config.withId(id));
		log.info("Registered provider {} (enabled: {})", id, saved.enabled());
		return saved;
	}

	/**
	 * Replaces a provider in db.json. A variable sent as "****" keeps its stored value, so secrets
	 * do not have to be sent again.
	 */
	public synchronized ProviderResponse update(String id, ProviderConfig config) {
		String normalized = requireValidId(id);
		String bodyId = normalizeId(config.id());
		if (bodyId != null && !bodyId.equals(normalized)) {
			throw new InvalidProviderException(
					"id in the body ('%s') does not match the id in the path ('%s')".formatted(bodyId, normalized));
		}
		Stored current = requireStored(normalized);

		Map<String, String> variables = new LinkedHashMap<>(config.variables());
		variables.replaceAll((name, value) -> MASK.equals(value) && current.config().variables().containsKey(name)
				? current.config().variables().get(name) : value);

		ProviderResponse saved = apply(config.withId(normalized).withVariables(variables));
		log.info("Updated provider {} (enabled: {})", normalized, saved.enabled());
		return saved;
	}

	/** Removes a provider from db.json. It stops being usable right away. */
	public synchronized void unregister(String id) {
		String normalized = requireValidId(id);
		requireStored(normalized);
		Map<String, Stored> next = new TreeMap<>(providers);
		next.remove(normalized);
		save(next);
		log.info("Unregistered provider {}", normalized);
	}

	/** Check, save, switch. Nothing changes when a check or the save fails. */
	private ProviderResponse apply(ProviderConfig config) {
		List<String> problems = new ArrayList<>(ExtensibleProvider.problems(config.toDescription()));
		List<String> empty = new ArrayList<>();
		config.variables().forEach((name, value) -> {
			if (value != null && value.contains("${")) {
				problems.add("variables.%s: send the real value; placeholders like ${...} are not supported"
					.formatted(name));
			}
			else if (MASK.equals(value)) {
				problems.add("variables.%s is \"%s\" but there is no stored value to keep".formatted(name, MASK));
			}
			else if (!StringUtils.hasText(value)) {
				empty.add(name);
			}
		});
		if (!empty.isEmpty() && config.enabled()) {
			problems.add("these variables have no value: %s; every variable needs one when the provider is enabled"
				.formatted(String.join(", ", empty)));
		}
		if (!problems.isEmpty()) {
			throw new InvalidProviderException(problems);
		}

		Map<String, Stored> next = new TreeMap<>(providers);
		next.put(config.id(), new Stored(config, build(config)));
		save(next);
		return response(config);
	}

	/** Saves to db.json first, then makes the new set live. */
	private void save(Map<String, Stored> next) {
		store.save(next.values().stream().map(Stored::config).toList());
		providers = Collections.unmodifiableMap(next);
	}

	private ExtensibleProvider build(ProviderConfig config) {
		return new ExtensibleProvider(config.id().toLowerCase(Locale.ROOT), config.toDescription(), builder.clone());
	}

	/** Secrets live in variables: a filled value becomes "****", an empty one stays empty. */
	private static ProviderResponse response(ProviderConfig config) {
		Map<String, String> variables = new LinkedHashMap<>();
		config.variables().forEach((name, value) -> variables.put(name, StringUtils.hasText(value) ? MASK : ""));
		return new ProviderResponse(config.id(), config.displayName(), config.channel(), config.enabled(), variables,
				config.systemVariables(), config.request(), config.response());
	}

	private Stored requireStored(String id) {
		Stored stored = (id == null) ? null : providers.get(id);
		if (stored == null) {
			throw new MessagingException(ErrorCode.PROVIDER_NOT_FOUND, null,
					"Provider '%s' was not found.".formatted(id));
		}
		return stored;
	}

	private static String requireValidId(String id) {
		String normalized = normalizeId(id);
		if (normalized == null) {
			throw new InvalidProviderException("id is missing");
		}
		if (!VALID_ID.matcher(normalized).matches()) {
			throw new InvalidProviderException(
					"id '%s' may only use letters, digits, '_' and '-'".formatted(id.trim()));
		}
		return normalized;
	}

	private static String normalizeId(String id) {
		return (id == null || id.isBlank()) ? null : id.trim().toUpperCase(Locale.ROOT);
	}

	/** A registered provider: the block as saved and the provider built from it. */
	private record Stored(ProviderConfig config, ExtensibleProvider provider) {
	}

}
