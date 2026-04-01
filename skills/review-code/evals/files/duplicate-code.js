/**
 * User notification preferences module.
 */

export function formatEmailNotification(user, event) {
  const timestamp = new Date(event.timestamp).toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });

  const greeting = user.preferredName
    ? `Hi ${user.preferredName}`
    : `Hi ${user.firstName}`;

  return {
    subject: `[${event.type.toUpperCase()}] ${event.summary}`,
    body: `${greeting},\n\nYou have a new ${event.type} notification:\n\n${event.summary}\n\nTime: ${timestamp}\n\nBest,\nThe Team`,
    recipient: user.email,
  };
}

export function formatSlackNotification(user, event) {
  const timestamp = new Date(event.timestamp).toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });

  const greeting = user.preferredName
    ? `Hi ${user.preferredName}`
    : `Hi ${user.firstName}`;

  return {
    channel: user.slackId,
    text: `${greeting}, you have a new *${event.type}* notification:\n>${event.summary}\n_${timestamp}_`,
  };
}

export function formatSMSNotification(user, event) {
  const timestamp = new Date(event.timestamp).toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });

  const name = user.preferredName || user.firstName;

  return {
    to: user.phoneNumber,
    body: `${name}: New ${event.type} - ${event.summary} (${timestamp})`,
  };
}
