public class ProjectTriggerHandler {

    // ─── After Insert ────────────────────────────────────────────────────────
    public void onAfterInsert(List<Project__c> newProjects) {
        Set<Id> siteIds = getSiteIds(newProjects);
        if (!siteIds.isEmpty()) {
            updateSiteFields(siteIds);
        }
    }

    // ─── After Update ────────────────────────────────────────────────────────
    public void onAfterUpdate(List<Project__c> newProjects, Map<Id, Project__c> oldMap) {
        Set<Id> siteIds = new Set<Id>();

        for (Project__c proj : newProjects) {
            Project__c oldProj = oldMap.get(proj.Id);

            Boolean inServiceAChanged = proj.In_Service_A__c != oldProj.In_Service_A__c;
            Boolean siteChanged       = proj.Site__c != oldProj.Site__c;

            if (inServiceAChanged || siteChanged) {
                if (proj.Site__c != null)    siteIds.add(proj.Site__c);
                if (oldProj.Site__c != null) siteIds.add(oldProj.Site__c); // old site must also be recalculated
            }
        }

        if (!siteIds.isEmpty()) {
            updateSiteFields(siteIds);
        }
    }

    // ─── After Delete ────────────────────────────────────────────────────────
    public void onAfterDelete(List<Project__c> oldProjects) {
        Set<Id> siteIds = getSiteIds(oldProjects);
        if (!siteIds.isEmpty()) {
            updateSiteFields(siteIds);
        }
    }

    // ─── After Undelete ──────────────────────────────────────────────────────
    public void onAfterUndelete(List<Project__c> newProjects) {
        Set<Id> siteIds = getSiteIds(newProjects);
        if (!siteIds.isEmpty()) {
            updateSiteFields(siteIds);
        }
    }

    // ─── Core Logic ──────────────────────────────────────────────────────────

    /**
     * Central method that:
     *   1. Counts all projects per Site  → Number_of_Projects__c
     *   2. Checks if ANY project has In_Service_A__c populated → Site_Status__c = 'On Air'
     *      Otherwise clears the status (set to null or a default value as needed)
     */
    private void updateSiteFields(Set<Id> siteIds) {

        // Aggregate: count of projects per site
        Map<Id, Integer> projectCountBySite = new Map<Id, Integer>();

        // Aggregate: whether any project has In_Service_A__c populated
        Map<Id, Boolean> hasOnAirBySite = new Map<Id, Boolean>();

        // Initialise maps for all sites (handles sites with zero remaining projects)
        for (Id siteId : siteIds) {
            projectCountBySite.put(siteId, 0);
            hasOnAirBySite.put(siteId, false);
        }

        // Query all remaining (non-deleted) projects for the affected sites
        List<Project__c> remainingProjects = [
            SELECT Id, Site__c, In_Service_A__c
            FROM   Project__c
            WHERE  Site__c IN :siteIds
        ];

        for (Project__c proj : remainingProjects) {
            // Increment count
            projectCountBySite.put(
                proj.Site__c,
                projectCountBySite.get(proj.Site__c) + 1
            );

            // Flag the site as 'On Air' if at least one project has In_Service_A__c
            if (proj.In_Service_A__c != null) {
                hasOnAirBySite.put(proj.Site__c, true);
            }
        }

        // Build the Site records to update
        List<Site__c> sitesToUpdate = new List<Site__c>();

        for (Id siteId : siteIds) {
            Site__c site = new Site__c(Id = siteId);

            // Requirement #3 – rollup count
            site.Number_of_Projects__c = projectCountBySite.get(siteId);

            // Requirement #2 – status based on In_Service_A__c across ALL linked projects
            if (hasOnAirBySite.get(siteId)) {
                site.Site_Status__c = 'On Air';
            } else {
                // No project has In_Service_A__c populated → clear the status
                site.Site_Status__c = null;
            }

            sitesToUpdate.add(site);
        }

        if (!sitesToUpdate.isEmpty()) {
            update sitesToUpdate;
        }
    }

    // ─── Helper ──────────────────────────────────────────────────────────────

    private Set<Id> getSiteIds(List<Project__c> projects) {
        Set<Id> siteIds = new Set<Id>();
        for (Project__c proj : projects) {
            if (proj.Site__c != null) {
                siteIds.add(proj.Site__c);
            }
        }
        return siteIds;
    }
}