package com.example.messaging_service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Incoming JSON for POST /api/v1/messages.
 *
 * @param provider id of a registered provider, e.g. "TWILIO"
 */
public record SendMessageRequest(
		@NotNull MessageType type,
		@NotBlank String provider,
		@NotBlank @Pattern(regexp = SendMessageRequest.E164, message = SendMessageRequest.E164_MESSAGE) String to,
		@NotBlank @Size(max = 1600) String body) {

	/** Phone number format for {@code to}: "+", country code, then the number. */
	public static final String E164 = "^\\+[1-9]\\d{7,14}$";

	public static final String E164_MESSAGE = "must be in E.164 format, for example +910000000001";

}
