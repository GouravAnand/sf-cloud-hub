import { LightningElement, api } from "lwc";

export default class PlatformEventSubscriberPanel extends LightningElement {
  @api statusLabel;
  @api eventCount;
  @api lastMessage;
  @api triggerError = false;

  get summaryText() {
    if (this.triggerError) {
      throw new Error("Simulated child component render error.");
    }

    return `${this.statusLabel} | Events received: ${this.eventCount}`;
  }
}
