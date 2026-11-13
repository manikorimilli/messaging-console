package com.example.messaging_service.dto;

import java.util.Map;

import com.example.messaging_service.provider.extensible.ExtensibleProviderDefinition.Request;
import com.example.messaging_service.provider.extensible.ExtensibleProviderDefinition.Response;
import com.fasterxml.jackson.annotation.JsonInclude;

import tools.jackson.databind.PropertyNamingStrategies.KebabCaseStrategy;
import tools.jackson.databind.annotation.JsonNaming;

/**
 * One provider as the provider APIs return it. Every filled variable is masked as "****".
 *
 * @param channel the channel the provider sends on, e.g. SMS
 * @param enabled true when the provider may send right now
 */
@JsonNaming(KebabCaseStrategy.class)
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ProviderResponse(String id, String displayName, MessageType channel, boolean enabled,
		Map<String, String> variables, Request request, Response response) {
}
