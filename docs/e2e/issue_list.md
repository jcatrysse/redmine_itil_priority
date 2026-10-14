# issue_list

Run 2026-10-14T23:32:30.257Z against http://127.0.0.1:3000.

| screenshot | user | URL | shows |
|---|---|---|---|
| ![](issue_list-columns-filter.png) | manager | `/projects/e2e-project/issues?set_filter=1&f[]=status_id&op[status_id]=o&f[]=impact_id&op[impact_id]=*&c[]=tracker&c[]=subject&c[]=priority&c[]=impact_id&c[]=urgency_id&sort=id:desc` | Issue list with the Impact and Urgency columns (labels, not numbers) and the filter "Impact: any" |
| ![](issue_list-filter-added.png) | manager | `/projects/e2e-project/issues?set_filter=1&sort=id%3Adesc&f%5B%5D=status_id&op%5Bstatus_id%5D=o&f%5B%5D=urgency_id&op%5Burgency_id%5D=%3D&v%5Burgency_id%5D%5B%5D=3&f%5B%5D=&c%5B%5D=subject&c%5B%5D=urgency_id&group_by=&t%5B%5D=` | Urgency filter added in the form: its labels load on demand, "Urgent" keeps only urgent issues |
| ![](issue_list-context-menu-operator.png) | manager | `/projects/e2e-project/issues?set_filter=1&f[]=status_id&op[status_id]=o&f[]=impact_id&op[impact_id]=*&c[]=tracker&c[]=subject&c[]=priority&c[]=impact_id&c[]=urgency_id&sort=id:desc` | Operator: the context menu has Priority, and Urgency/Impact with their labels and the submenu arrow |
| ![](issue_list-context-menu-applied.png) | manager | `/issues/24` | Urgency set through the context menu; history shows the change with its label |
| ![](issue_list-context-menu-helpdesk.png) | reporter | `/projects/e2e-project/issues` | Helpdesk user: no Priority in the context menu, Urgency and Impact are there |
| ![](issue_list-bulk-edit-helpdesk.png) | reporter | `/issues/bulk_edit?ids%5B%5D=23&ids%5B%5D=24` | Bulk edit as helpdesk user: Urgency and Impact, no Priority |
| ![](issue_list-bulk-edit-result.png) | reporter | `/projects/e2e-project/issues?set_filter=1&f[]=impact_id&op[impact_id]==&v[impact_id][]=2&f[]=urgency_id&op[urgency_id]==&v[urgency_id][]=2&c[]=subject&c[]=priority&c[]=impact_id&c[]=urgency_id` | After the bulk edit, filtered on Impact = Medium and Urgency = Normal: the issues have priority Normal from the matrix |
