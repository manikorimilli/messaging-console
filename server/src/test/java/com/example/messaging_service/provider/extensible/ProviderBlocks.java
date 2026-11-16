package com.example.messaging_service.provider.extensible;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.web.client.RestClient;

import com.example.messaging_service.dto.ProviderConfig;
import com.example.messaging_service.provider.extensible.ExtensibleProviderDefinition.Description;

import tools.jackson.databind.json.JsonMapper;

/**
 * Loads a provider from src/test/resources/providers (in the registration format), with test values for its variables.
 */
final class ProviderBlocks {

	private static final JsonMapper JSON = JsonMapper.builder().build();

	private ProviderBlocks() {
	}

	static Description load(String name, Map<String, String> variables) {
		try (InputStream in = ProviderBlocks.class.getResourceAsStream("/providers/" + name + ".json")) {
			ProviderConfig config = JSON.readValue(in, ProviderConfig.class);
			Map<String, String> values = new LinkedHashMap<>(config.variables());
			values.putAll(variables);
			return config.withVariables(values).toDescription();
		}
		catch (IOException e) {
			throw new UncheckedIOException(e);
		}
	}

	static ExtensibleProvider provider(String name, Map<String, String> variables, RestClient.Builder builder) {
		return new ExtensibleProvider(name, load(name, variables), builder);
	}

}
