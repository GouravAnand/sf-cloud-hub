import { LightningElement, wire } from "lwc";
import searchAccounts from "@salesforce/apex/AccountContactController.searchAccounts";

export default class ParentCmp1 extends LightningElement {
  searchKey = "";
  selectedAccountId;
  selectedAccountName;

  accounts = [];
  error;

  @wire(searchAccounts, { searchKey: "$searchKey" })
  wiredAccounts({ data, error }) {
    if (data) {
      this.accounts = data;
      this.error = undefined;
      return;
    }

    if (error) {
      this.accounts = [];
      this.error = error;
    }
  }

  handleSearchChange(event) {
    this.searchKey = event.target.value;
    this.selectedAccountId = undefined;
    this.selectedAccountName = undefined;
  }

  handleAccountSelect(event) {
    this.selectedAccountId = event.currentTarget.dataset.id;
    this.selectedAccountName = event.currentTarget.dataset.name;
  }

  get hasAccounts() {
    return this.accounts && this.accounts.length > 0;
  }

  get hasSelectedAccount() {
    return Boolean(this.selectedAccountId);
  }
}
