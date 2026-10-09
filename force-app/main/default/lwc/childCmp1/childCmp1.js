import { LightningElement, api, wire } from "lwc";
import getContactsByAccount from "@salesforce/apex/AccountContactController.getContactsByAccount";

export default class ChildCmp1 extends LightningElement {
  contacts = [];
  error;

  columns = [
    { label: "Name", fieldName: "Name", type: "text" },
    { label: "Email", fieldName: "Email", type: "email" },
    { label: "Phone", fieldName: "Phone", type: "phone" }
  ];

  _accountId;

  @api
  get accountId() {
    return this._accountId;
  }
  set accountId(value) {
    this._accountId = value;
  }

  @wire(getContactsByAccount, { accountId: "$_accountId" })
  wiredContacts({ data, error }) {
    if (data) {
      this.contacts = data;
      this.error = undefined;
      return;
    }

    if (error) {
      this.contacts = [];
      this.error = error;
    }
  }

  get hasContacts() {
    return this.contacts && this.contacts.length > 0;
  }
}
