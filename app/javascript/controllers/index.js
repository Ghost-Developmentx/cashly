// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"

import CashFlowChartController from "./cash_flow_chart_controller"
application.register("cash-flow-chart", CashFlowChartController)

import BudgetVsActualChartController from "./budget_vs_actual_chart_controller"
application.register("budget-vs-actual-chart", BudgetVsActualChartController)

import CategorySpendingChartController from "./category_spending_chart_controller"
application.register("category-spending-chart", CategorySpendingChartController)

import FinancialInsightsController from "./financial_insights_chart_controller"
application.register("financial-insights", FinancialInsightsController)

import FinAssistantController from "./fin_assistant_controller"
application.register("fin-assistant", FinAssistantController)

import ReconciliationController from "./reconciliation_controller"
application.register("reconciliation", ReconciliationController)

import TemplateSelectorController from "./template_selector_controller"
application.register("template-selector", TemplateSelectorController)

import InvoicePreviewController from "./invoice_preview_controller"
application.register("invoice-preview", InvoicePreviewController)

import SidebarController from "./sidebar_controller"
application.register("sidebar", SidebarController)

import ForecastChartController from "./forecast_chart_controller"
application.register("forecast-chart", ForecastChartController)

import ScenarioChartController from "./scenario_chart_controller"
application.register("scenario-chart", ScenarioChartController)

import CompareChartController from "./compare_chart_controller"
application.register("compare-chart", CompareChartController)

import DefaultForecastChartController from "./default_forecast_chart_controller"
application.register("default-forecast-chart", DefaultForecastChartController)

import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
