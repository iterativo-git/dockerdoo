echo "*********************************"
echo "*                               *"
echo "*    Install Enterprise Code    *"
echo "*                               *"
echo "*********************************"
git clone --depth 10 --branch 11.0 git@github.com:odoo/enterprise.git custom/odoo/enterprise

# OCA ADDONS
echo "*********************************"
echo "*                               *"
echo "*      Install OCA Addons       *"
echo "*                               *"
echo "*********************************"

echo -e "\n---- Install OCA Principal Addons ----"
git clone --depth 10 --branch 11.0 https://github.com/OCA/partner-contact.git custom/oca/partner-contact
git clone --depth 10 --branch 11.0 https://github.com/OCA/web.git custom/oca/web
git clone --depth 10 --branch 11.0 https://github.com/OCA/server-tools.git custom/oca/server-tools
git clone --depth 10 --branch 11.0 https://github.com/OCA/server-auth.git custom/oca/server-auth
git clone --depth 10 --branch 11.0 https://github.com/OCA/server-ux.git custom/oca/server-ux
git clone --depth 10 --branch 11.0 https://github.com/OCA/reporting-engine.git custom/oca/reporting-engine
git clone --depth 10 --branch 11.0 https://github.com/OCA/sale-workflow.git custom/oca/sale-workflow
git clone --depth 10 --branch 11.0 https://github.com/OCA/purchase-workflow.git custom/oca/purchase-workflow
git clone --depth 10 --branch 11.0 https://github.com/OCA/stock-logistics-workflow.git custom/oca/stock-logistics-workflow
git clone --depth 10 --branch 11.0 https://github.com/OCA/stock-logistics-warehouse.git custom/oca/stock-logistics-warehouse
git clone --depth 10 --branch 11.0 https://github.com/OCA/account-payment.git custom/oca/account-payment
git clone --depth 10 --branch 11.0 https://github.com/OCA/account-financial-tools.git custom/oca/account-financial-tools
git clone --depth 10 --branch 11.0 https://github.com/OCA/account-financial-reporting.git custom/oca/account-financial-reporting
git clone --depth 10 --branch 11.0 https://github.com/OCA/pos.git custom/oca/pos
git clone --depth 10 --branch 11.0 https://github.com/OCA/account-invoicing.git custom/oca/account-invoicing
git clone --depth 10 --branch 11.0 https://github.com/OCA/bank-statement-import.git custom/oca/bank-statement-import
git clone --depth 10 --branch 11.0 https://github.com/OCA/bank-statement-reconcile.git custom/oca/bank-statement-reconcile
git clone --depth 10 --branch 11.0 https://github.com/OCA/bank-payment.git custom/oca/bank-payment
git clone --depth 10 --branch 11.0 https://github.com/OCA/account-fiscal-rule.git custom/oca/account-fiscal-rule
git clone --depth 10 --branch 11.0 git@github.com:OCA/credit-control.git custom/oca/credit-control
git clone --depth 10 --branch 11.0 git@github.com:OCA/account-analytic.git custom/oca/account-analytic

echo -e "\n---- Install OCA Optional Addons ----"
git clone --depth 10 --branch 11.0 https://github.com/OCA/contract.git custom/oca/contract
git clone --depth 10 --branch 11.0 https://github.com/OCA/product-variant.git custom/oca/product-variant
git clone --depth 10 --branch 11.0 https://github.com/OCA/multi-company.git custom/oca/multi-company
git clone --depth 10 --branch 11.0 https://github.com/OCA/business-requirement.git custom/oca/business-requirement
git clone --depth 10 --branch 11.0 https://github.com/OCA/operating-unit.git custom/oca/operating-unit
git clone --depth 10 --branch 11.0 https://github.com/OCA/hr.git custom/oca/hr
# git clone --depth 10 --branch 11.0 git@github.com:OCA/currency.git custom/oca/currency
git clone --depth 10 --branch 11.0 git@github.com:OCA/product-attribute.git custom/oca/product-attribute
# git clone --depth 10 --branch 11.0 git@github.com:OCA/report-print-send.git custom/oca/report-print-send
git clone --depth 10 --branch 11.0 git@github.com:OCA/manufacture.git custom/oca/manufacture
git clone --depth 10 --branch 11.0 git@github.com:OCA/commission.git custom/oca/commission
git clone --depth 10 --branch 11.0 git@github.com:OCA/event.git custom/oca/event
git clone --depth 10 --branch 11.0 git@github.com:OCA/queue.git custom/oca/queue
git clone --depth 10 --branch 11.0 git@github.com:OCA/rest-framework.git custom/oca/rest-framework
git clone --depth 10 --branch 11.0 git@github.com:OCA/connector.git custom/oca/connector

# Ivan Yelizariev Addons
echo "*********************************"
echo "*                               *"
echo "*  Install IT Projects Addons   *"
echo "*                               *"
echo "*********************************"
echo -e "\n---- Install Yelizariev Addons ----"
git clone --depth 10 --branch 11.0 https://github.com/it-projects-llc/access-addons.git custom/it-projects-llc/security
git clone --depth 10 --branch 11.0 https://github.com/it-projects-llc/mail-addons.git custom/it-projects-llc/mail-addons
git clone --depth 10 --branch 11.0 https://github.com/it-projects-llc/misc-addons.git custom/it-projects-llc/misc-addons
git clone --depth 10 --branch 11.0 https://github.com/it-projects-llc/website-addons.git custom/it-projects-llc/website-addons
git clone --depth 10 --branch 11.0 https://github.com/it-projects-llc/pos-addons.git custom/it-projects-llc/pos-addons
git clone --depth 10 --branch 11.0 https://github.com/it-projects-llc/access-addons.git custom/it-projects-llc/access-addons

echo "*********************************"
echo "*                               *"
echo "*  Install Localization Addons  *"
echo "*                               *"
echo "*********************************"
git clone --depth 10 --branch 11.0 git@github.com:odoo-dominicana/l10n-dominicana.git custom/iterativo/l10n-dominicana
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/dominicana-premium.git custom/iterativo/dominicana-premium
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/iterativo-premium.git custom/iterativo/iterativo-premium
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/dominican_bank_statement.git custom/iterativo/dominican_bank_statement
git clone --depth 10 --branch 11.0 git@github.com:iterativo-git/l10n_do_hr_payroll.git custom/iterativo/l10n_do_hr_payroll
git clone --depth 10 --branch 11.0 git@github.com:iterativo-git/tss_report.git custom/iterativo/tss_report
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/fiscal-reports.git custom/iterativo/fiscal-reports
git clone --depth 10 --branch 11.0 git@github.com:iterativo-git/ipf-manager.git custom/iterativo/ipf-manager

echo "*********************************"
echo "*                               *"
echo "*  Install iterativo SRL Extras *"
echo "*                               *"
echo "*********************************"
echo -e "\n---- Install iterativo General Addons  ----"
git clone --depth 10 --branch 11.0 git@github.com:iterativo-git/odoo-qztray.git custom/iterativo/odoo-zebra

echo "*********************************"
echo "*                               *"
echo "*  Install INDEXA addons Extras *"
echo "*                               *"
echo "*********************************"
echo -e "\n---- Install iterativo General Addons  ----"
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/external_service_addons.git custom/indexa/external_service_addons
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/odoo-general.git custom/iterativo/odoo-general
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/odoo-store.git custom/iterativo/odoo-store
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/pid.git custom/iterativo/pid
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/odoo-wenigas.git custom/iterativo/odoo-wenigas
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/odoo-incocegla.git custom/iterativo/odoo-incocegla
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/sale.git custom/indexa/sale
git clone --depth 10 --branch master git@github.com:indexa-git/odoo-pos.git custom/indexa/odoo-pos
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/odoo-pid.git custom/indexa/odoo-pid
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/odoo-andrea.git custom/indexa/odoo-andrea
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/odoo-tekgraf.git custom/indexa/odoo-tekgraf
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/account_bank_charge_import.git custom/indexa/account_bank_charge_import
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/stock.git custom/indexa/stock
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/maintenance.git custom/indexa/maintenance
git clone --depth 10 --branch 11.0 git@github.com:indexa-git/account.git custom/indexa/account


echo "*********************************"
echo "*                               *"
echo "*  Show files that are in here  *"
echo "*                               *"
echo "*********************************" 
echo -e "\n---- ls  ----"
cp -a custom/ /src
