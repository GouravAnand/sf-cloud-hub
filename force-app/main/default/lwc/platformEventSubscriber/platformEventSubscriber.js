import { LightningElement } from "lwc";
import {
  subscribe,
  unsubscribe,
  onError,
  setDebugFlag,
  isEmpEnabled
} from "lightning/empApi";

export default class PlatformEventSubscriber extends LightningElement {
  channelName;
  subscription;
  events;
  lastMessage;
  error;
  isConnected;
  columns;
  hasRendered = false;
  canSubscribe = false;
  subscriptionAttempted = false;
  triggerChildError = false;

  constructor() {
    super();
    this.channelName = "/event/PlatformMessage__e";
    this.subscription = null;
    this.events = [];
    this.lastMessage = null;
    this.isConnected = false;
    this.columns = [
      { label: "Replay Id", fieldName: "id", type: "number" },
      { label: "Message", fieldName: "message", type: "text" },
      { label: "Category", fieldName: "category", type: "text" },
      { label: "Source", fieldName: "source", type: "text" },
      { label: "Created", fieldName: "createdDate", type: "text" }
    ];
  }

  async connectedCallback() {
    const enabled = await isEmpEnabled();

    if (!enabled) {
      this.error = "EMP API is not enabled in this org.";
      return;
    }

    setDebugFlag(false);
    this.registerErrorListener();
    this.canSubscribe = true;
  }

  renderedCallback() {
    if (!this.hasRendered) {
      this.hasRendered = true;
    }

    if (this.canSubscribe && !this.subscriptionAttempted) {
      this.subscriptionAttempted = true;
      this.subscribeToChannel();
    }
  }

  disconnectedCallback() {
    this.unsubscribeFromChannel();
  }

  errorCallback(error) {
    this.error = error?.message || "An unexpected subscriber error occurred.";
    this.isConnected = false;
  }

  async subscribeToChannel() {
    if (this.subscription) {
      return;
    }

    const messageCallback = (message) => {
      // This runs the moment the event is published and delivered
      console.log("Event received:", message);
      this.lastMessage = message.data.payload;

      const payload = message.data.payload;
      const incomingEvent = {
        id: message.data.event.replayId,
        message: payload.Message__c,
        category: payload.Category__c,
        source: payload.Source__c,
        createdDate: message.data.event.createdDate
      };

      this.events = [incomingEvent, ...this.events];
      this.isConnected = true;
      this.error = undefined;
      // Update UI, dispatch custom event, etc.
    };

    // replayId:
    // -1  = new events only (recommended for “from now on”)
    // -2  = replay from earliest stored event (within retention)
    subscribe(this.channelName, -1, messageCallback)
      .then((response) => {
        this.subscription = response;
        this.isConnected = true;
        console.log("Subscribed to:", response.channel);
      })
      .catch((err) => {
        this.error = err?.message || "Failed to subscribe.";
        console.error("Subscription error:", err);
      });
  }

  async unsubscribeFromChannel() {
    if (!this.subscription) {
      this.isConnected = false;
      return;
    }

    try {
      await unsubscribe(this.subscription);
      this.subscription = null;
      this.isConnected = false;
      this.subscriptionAttempted = false;
    } catch (unsubscribeError) {
      this.error = unsubscribeError?.message || "Failed to unsubscribe.";
    }
  }

  registerErrorListener() {
    onError((error) => {
      this.error = error?.message || "Unknown streaming error.";
      this.isConnected = false;
    });
  }

  handleToggleConnection() {
    if (this.subscription) {
      this.unsubscribeFromChannel();
      return;
    }

    this.subscriptionAttempted = false;
    this.canSubscribe = true;
    this.subscribeToChannel();
  }

  handleToggleChildError() {
    this.triggerChildError = !this.triggerChildError;
  }

  get hasEvents() {
    return this.events && this.events.length > 0;
  }

  get connectionLabel() {
    return this.isConnected ? "Connected" : "Disconnected";
  }

  get toggleLabel() {
    return this.subscription ? "Unsubscribe" : "Reconnect";
  }

  get childErrorLabel() {
    return this.triggerChildError
      ? "Disable Child Error"
      : "Simulate Child Error";
  }

  get latestMessageText() {
    return this.lastMessage ? this.lastMessage.Message__c : "";
  }
}
