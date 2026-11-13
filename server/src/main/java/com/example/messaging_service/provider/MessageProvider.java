package com.example.messaging_service.provider;

import com.example.messaging_service.dto.MessageType;

/**
 * What sending needs from a provider. {@link com.example.messaging_service.provider.extensible.ExtensibleProvider}
 * is the implementation; tests use fakes.
 */
public interface MessageProvider {

	/** Stable upper-case provider id used in requests, e.g. "TWILIO". */
	String id();

	/** The channel this provider sends on, e.g. SMS. */
	MessageType channel();

	/** False when credentials are missing. Checked at startup for every enabled provider. */
	default boolean isConfigured() {
		return true;
	}

	/**
	 * Sends one message. Returns when the provider has ACCEPTED it (not when it is delivered).
	 * Throws MessagingException (PROVIDER_REJECTED or PROVIDER_UNAVAILABLE) when the provider
	 * answers with an error.
	 */
	ProviderResult send(OutboundMessage message);

}
