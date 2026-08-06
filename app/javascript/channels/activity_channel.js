import { createConsumer } from "@rails/actioncable"

const consumer = createConsumer();

const subscription = consumer.subscriptions.create("ActivityChannel", {
  connected() {
    // Called when the subscription is ready for use on the server
  },

  disconnected() {
    // Called when the subscription has been terminated by the server
  },

  received(data) {
    const activitiesContainer = document.getElementById('activities');
    const activityElement = document.createElement('div');
    activityElement.innerHTML = `
      <div class="activity">
        <p><strong>${data.user.username}</strong>: ${data.description}</p>
        <p>${data.created_at}</p>
      </div>
    `;
    activitiesContainer.prepend(activityElement);
  }
});

export default subscription;
