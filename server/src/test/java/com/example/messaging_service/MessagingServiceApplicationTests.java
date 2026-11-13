package com.example.messaging_service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Duration;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.http.client.ClientHttpRequestFactoryBuilder;
import org.springframework.boot.http.client.HttpClientSettings;
import org.springframework.boot.http.client.JdkClientHttpRequestFactoryBuilder;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import com.example.messaging_service.dto.MessageType;
import com.example.messaging_service.service.ProviderRegistry;

/**
 * The whole application with both real adapters and dummy credentials. No request here reaches
 * a provider; adapter HTTP calls are covered by the adapter tests.
 */
@SpringBootTest(properties = "messaging.db-file=target/test-db/MessagingServiceApplicationTests.json")
@AutoConfigureMockMvc
class MessagingServiceApplicationTests {

	@Autowired
	private MockMvc mvc;

	@Test
	void httpClientIsJdkWithConfiguredTimeouts(@Autowired ClientHttpRequestFactoryBuilder<?> factoryBuilder,
			@Autowired HttpClientSettings settings) {
		assertThat(factoryBuilder).isInstanceOf(JdkClientHttpRequestFactoryBuilder.class);
		assertThat(settings.connectTimeout()).isEqualTo(Duration.ofSeconds(2));
		assertThat(settings.readTimeout()).isEqualTo(Duration.ofSeconds(10));
	}

	@Test
	void startsWithNoProviders() throws Exception {
		mvc.perform(get("/api/v1/providers")).andExpect(status().isOk()).andExpect(content().json("[]"));
	}

	@Test
	void sendMustNameAProvider() throws Exception {
		send("""
				{ "type": "SMS", "to": "+910000000001", "body": "Hi" }
				""").andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
			.andExpect(jsonPath("$.errors[0].field").value("provider"));
	}

	@Test
	void unknownProviderSaysNoneAreRegistered() throws Exception {
		send("""
				{ "type": "SMS", "provider": "SINCH", "to": "+910000000001", "body": "Hi" }
				""").andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("UNSUPPORTED_PROVIDER"))
			.andExpect(jsonPath("$.detail")
				.value("Provider 'SINCH' is not registered. No providers are registered."));
	}

	@Test
	void invalidRequestIsRejectedBeforeAnyProviderIsCalled() throws Exception {
		send("""
				{ "type": "SMS", "to": "12345", "body": "" }
				""").andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
	}

	@Test
	void healthCheckIsUpWithoutDetails() throws Exception {
		mvc.perform(get("/actuator/health"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.status").value("UP"))
			.andExpect(jsonPath("$.components").doesNotExist());
	}

	@Test
	void otherActuatorEndpointsAreNotExposed() throws Exception {
		mvc.perform(get("/actuator/env")).andExpect(status().isNotFound());
	}

	private ResultActions send(String json) throws Exception {
		return mvc.perform(post("/api/v1/messages").contentType(MediaType.APPLICATION_JSON).content(json));
	}

}
