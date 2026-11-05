# Rolling out a guardrail

1. Add the definition (a JSON file in `terraform/modules/policy/definitions`
   for a custom one) and the assignment.
2. Add the assignment name to `policy_do_not_enforce`. Merge: the assignment
   evaluates and reports, but denies nothing.
3. Wait for a compliance scan (up to 24 hours, or
   `az policy state trigger-scan --resource-group <rg>`), then list what would
   have been denied:

   ```bash
   az policy state list --management-group alz \
     --filter "PolicyAssignmentName eq '<name>' and ComplianceState eq 'NonCompliant'" \
     --query "[].{resource:resourceId, sub:subscriptionId}" -o table
   ```

4. Fix the resources, or agree an exemption with an expiry date for the ones
   that cannot change yet:

   ```bash
   az policy exemption create --name <name>-<workload> \
     --policy-assignment <assignment id> --scope <resource id> \
     --exemption-category Waiver --expires-on 2027-03-31 --description "<ticket>"
   ```

5. Remove the name from `policy_do_not_enforce`. From the next apply, the
   rule denies.

For the subnet NSG rule, step 5 is setting `subnet_nsg_effect = "Deny"`.
