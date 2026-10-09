import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import publishPlatformMessage from "@salesforce/apex/PlatformEventController.publishPlatformMessage";

export default class PlatformEventPublisher extends LightningElement {
  @track message;
  @track category;
  error;
  isLoading;
  hasRendered = false;

  constructor() {
    super();
    this.message = "";
    this.category = "General";
    this.isLoading = false;
  }

  renderedCallback() {
    if (this.hasRendered) {
      return;
    }

    this.hasRendered = true;

    const messageBox = this.template.querySelector("lightning-textarea");
    if (messageBox?.focus) {
      messageBox.focus();
    }
  }

  errorCallback(error) {
    const message =
      error?.message || "An unexpected error occurred in the publisher.";
    this.error = message;
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Component Error",
        message,
        variant: "error"
      })
    );
  }

  handleMessageChange(event) {
    this.message = event.target.value;
  }

  handleCategoryChange(event) {
    this.category = event.target.value;
  }

  async handlePublish() {
    this.isLoading = true;
    try {
      const response = await publishPlatformMessage({
        message: this.message,
        category: this.category
      });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: response,
          variant: "success"
        })
      );
      this.message = "";
      this.category = "General";
    } catch (error) {
      this.error =
        error?.body?.message ||
        error?.message ||
        "Failed to publish platform event.";
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: this.error,
          variant: "error"
        })
      );
    } finally {
      this.isLoading = false;
    }
  }

  get isPublishDisabled() {
    return this.isLoading || !this.message.trim();
  }
}
