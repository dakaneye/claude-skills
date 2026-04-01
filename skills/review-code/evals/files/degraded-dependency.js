/**
 * Notification service that sends alerts via external provider.
 */

const PROVIDER_URL = process.env.NOTIFICATION_PROVIDER_URL;

export async function sendNotification(userId, message, channel) {
  const payload = {
    recipient: userId,
    body: message,
    channel: channel || "email",
    timestamp: new Date().toISOString(),
  };

  const response = await fetch(PROVIDER_URL + "/api/v1/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${process.env.NOTIFICATION_API_KEY}`,
    },
    body: JSON.stringify(payload),
  });

  const result = await response.json();
  return result;
}

export async function sendBulkNotifications(userIds, message) {
  const results = [];
  for (const userId of userIds) {
    const result = await sendNotification(userId, message);
    results.push(result);
  }
  return results;
}
