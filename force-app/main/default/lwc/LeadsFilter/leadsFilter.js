import { LightningElement, wire } from "lwc";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import LEAD_OBJECT from "@salesforce/schema/Lead";
import STATUS_FIELD from "@salesforce/schema/Lead.Status";
import getLeads from "@salesforce/apex/LeadsFilterController.getLeads";

export default class LeadsFilter extends LightningElement {
  selectedStatus = "";
  statusOptions = [{ label: "All", value: "" }];
  leads = [];
  error;
  recordTypeId;

  @wire(getObjectInfo, { objectApiName: LEAD_OBJECT })
  wiredObjectInfo({ data, error }) {
    if (data) {
      this.recordTypeId = data.defaultRecordTypeId;
      this.error = undefined;
    } else if (error) {
      this.error = error;
    }
  }

  @wire(getPicklistValues, {
    recordTypeId: "$recordTypeId",
    fieldApiName: STATUS_FIELD
  })
  wiredStatuses({ data, error }) {
    if (data) {
      this.statusOptions = [
        { label: "All", value: "" },
        ...data.values.map((item) => ({
          label: item.label,
          value: item.value
        }))
      ];
      this.error = undefined;
    } else if (error) {
      this.error = error;
    }
  }

  @wire(getLeads, { statusFilter: "$selectedStatus" })
  wiredLeads({ data, error }) {
    if (data) {
      this.leads = data;
      this.error = undefined;
    } else if (error) {
      this.leads = [];
      this.error = error;
    }
  }

  handleStatusChange(event) {
    this.selectedStatus = event.detail.value;
  }

  get hasLeads() {
    return this.leads && this.leads.length > 0;
  }
}
