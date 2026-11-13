package com.example.messaging_service.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.web.client.RestClient;

import com.example.messaging_service.ProviderExamples;
import com.example.messaging_service.dto.MessageType;
import com.example.messaging_service.dto.ProviderConfig;
import com.example.messaging_service.exception.ErrorCode;
import com.example.messaging_service.exception.MessagingException;
import com.example.messaging_service.provider.store.ProviderStore;

/** Which provider a request gets, and what the registry accepts at startup. */
class ProviderRegistryTest {

	private final ProviderStore store = ProviderStore.inMemory();

	@Test
	void resolvesARegisteredEnabledProviderWhateverTheCase() {
		ProviderRegistry registry = registryWith(ProviderExamples.plivo());

		assertThat(registry.resolve(" plivo ", MessageType.SMS).id()).isEqualTo("PLIVO");
	}

	@Test
	void unknownProviderListsTheRegisteredOnes() {
		ProviderRegistry registry = registryWith(ProviderExamples.plivo());

		assertCode(() -> registry.resolve("SINCH", MessageType.SMS), ErrorCode.UNSUPPORTED_PROVIDER,
				"Provider 'SINCH' is not registered. Registered providers: PLIVO.");
	}

	@Test
	void sayWhenNoProvidersAreRegistered() {
		ProviderRegistry registry = registryWith();

		assertCode(() -> registry.resolve("TWILIO", MessageType.SMS), ErrorCode.UNSUPPORTED_PROVIDER,
				"Provider 'TWILIO' is not registered. No providers are registered.");
		assertThat(registry.providers()).isEmpty();
	}

	@Test
	void disabledProviderIsUnavailable() {
		ProviderRegistry registry = registryWith(ProviderExamples.plivo(false, ProviderExamples.plivoVariables()));

		assertCode(() -> registry.resolve("PLIVO", MessageType.SMS), ErrorCode.PROVIDER_UNAVAILABLE,
				"Provider 'PLIVO' is disabled.");
	}

	@Test
	void listsProvidersWithSecretsMasked() {
		ProviderRegistry registry = registryWith(ProviderExamples.plivo());

		assertThat(registry.providers()).singleElement().satisfies(provider -> {
			assertThat(provider.id()).isEqualTo("PLIVO");
			assertThat(provider.channel()).isEqualTo(MessageType.SMS);
			assertThat(provider.enabled()).isTrue();
			assertThat(provider.variables()).containsOnlyKeys("auth-id", "auth-token", "from")
				.allSatisfy((name, value) -> assertThat(value).isEqualTo("****"));
		});
	}

	@Test
	void startupFailsOnABrokenEntryInDbJson() {
		store.save(List.of(ProviderExamples.plivo().withId("pl ivo")));

		assertThatThrownBy(() -> new ProviderRegistry(RestClient.builder(), store))
			.isInstanceOf(IllegalStateException.class)
			.hasMessageContaining("has a provider with id 'pl ivo'");
	}

	@Test
	void startupFailsWhenAnEnabledProviderHasNoCredentials() {
		Map<String, String> noToken = ProviderExamples.plivoVariables();
		noToken.put("auth-token", "");
		store.save(List.of(ProviderExamples.plivo(true, noToken)));

		assertThatThrownBy(() -> new ProviderRegistry(RestClient.builder(), store))
			.hasMessageContaining("PLIVO is enabled in")
			.hasMessageContaining("but its credentials are missing");
	}

	private ProviderRegistry registryWith(ProviderConfig... providers) {
		store.save(List.of(providers));
		return new ProviderRegistry(RestClient.builder(), store);
	}

	private static void assertCode(Runnable call, ErrorCode code, String message) {
		assertThatThrownBy(call::run).isInstanceOfSatisfying(MessagingException.class, e -> {
			assertThat(e.code()).isEqualTo(code);
			assertThat(e.getMessage()).isEqualTo(message);
		});
	}

}
