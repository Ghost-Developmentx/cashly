// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"

import CashFlowChartController from "./cash_flow_chart_controller"
application.register("cash-flow-chart", CashFlowChartController)

import BudgetVsActualChartController from "./budget_vs_actual_chart_controller"
application.register("budget-vs-actual-chart", BudgetVsActualChartController)

import CategorySpendingChartController from "./category_spending_chart_controller"
application.register("category-spending-chart", CategorySpendingChartController)

import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
