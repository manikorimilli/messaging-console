package com.example.messaging_service.dto;

import java.util.Arrays;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

import com.example.messaging_service.provider.extensible.ExtensibleProviderDefinition.Description;
import com.example.messaging_service.provider.extensible.ExtensibleProviderDefinition.Request;
import com.example.messaging_service.provider.extensible.ExtensibleProviderDefinition.Response;
import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

import tools.jackson.databind.PropertyNamingStrategies.KebabCaseStrategy;
import tools.jackson.databind.annotation.JsonNaming;

/**
 * One registered provider: its definition plus {@code enabled}. A provider serves one channel;
 * the same account on another channel is registered again. It is the request body of POST and PUT
 * /api/v1/providers and the format stored in db.json.
 *
 * @param channel the channel this provider sends on, e.g. SMS
 * @param enabled true when the provider may send; missing means false
 * @param variables raw values (secrets and settings) usable as {{name}} in templates
 * @param systemVariables documents the uaap.* placeholders this provider uses, e.g. {"uaap.to": "",
 * "uaap.text": ""}. Always filled from the message at send time: values entered here are ignored.
 */
@JsonNaming(KebabCaseStrategy.class)
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ProviderConfig(String id, String displayName, MessageType channel, Boolean enabled,
		Map<String, String> variables, Map<String, String> systemVariables, Request request, Response response) {

	public ProviderConfig {
		// Boolean, not boolean: Jackson 3 rejects a missing primitive, and a missing value means false.
		enabled = Boolean.TRUE.equals(enabled);
		variables = (variables == null) ? Map.of() : Collections.unmodifiableMap(new LinkedHashMap<>(variables));
		systemVariables = (systemVariables == null) ? Map.of()
				: Collections.unmodifiableMap(new LinkedHashMap<>(systemVariables));
	}

	@JsonCreator
	public static ProviderConfig fromJson(@JsonProperty("id") String id,
			@JsonProperty("display-name") String displayName, @JsonProperty("channel") String channel,
			@JsonProperty("enabled") Boolean enabled, @JsonProperty("variables") Map<String, String> variables,
			@JsonProperty("system-variables") Map<String, String> systemVariables,
			@JsonProperty("request") Request request, @JsonProperty("response") Response response) {
		return new ProviderConfig(id, displayName, parseChannel(channel), enabled, variables, systemVariables, request,
				response);
	}

	private static MessageType parseChannel(String value) {
		try {
			return MessageType.from(value);
		}
		catch (IllegalArgumentException e) {
			throw new IllegalArgumentException("channel must be one of " + Arrays.toString(MessageType.values()));
		}
	}

	public Description toDescription() {
		return new Description(id, displayName, channel, variables, request, response);
	}

	public ProviderConfig withId(String newId) {
		return new ProviderConfig(newId, displayName, channel, enabled, variables, systemVariables, request, response);
	}

	public ProviderConfig withVariables(Map<String, String> newVariables) {
		return new ProviderConfig(id, displayName, channel, enabled, newVariables, systemVariables, request, response);
	}

}
