import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts";

export default class extends Controller {
    static targets = ["chartContainer"]

    connect() {
        console.log("Scenario Chart Controller Connected");

        // Initialize the empty chart for scenarios to be filled in later
        this.initializeScenarioChart();

        // Set up transactionCount for the dynamic form fields
        this.transactionCount = 1;

        // Add event listener for adding new transactions
        this.setupEventListeners();
    }

    initializeScenarioChart() {
        // This could be used to show a placeholder chart or instructions
        // For now, just showing a message that the scenario chart will appear after creation
        if (this.hasChartContainerTarget) {
            this.chartContainerTarget.innerHTML =
                '<div class="text-center p-10 bg-gray-50 rounded-lg">' +
                '<svg class="w-12 h-12 text-gray-400 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">' +
                '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>' +
                '</svg>' +
                '<p class="text-gray-600">Your scenario chart will appear here after creation</p>' +
                '</div>';
        }
    }

    setupEventListeners() {
        // Find the added recurring transaction button and add an event listener
        const addButton = document.getElementById('add-recurring');
        if (addButton) {
            addButton.addEventListener('click', this.addRecurringTransaction.bind(this));
        }
    }

    addRecurringTransaction() {
        const container = document.getElementById('recurring-transactions');
        if (!container) return;

        // Clone the first transaction div
        const templateTransaction = document.querySelector('.recurring-transaction');
        if (!templateTransaction) return;

        const newTransaction = templateTransaction.cloneNode(true);

        // Update all the field names to use the new index
        const inputs = newTransaction.querySelectorAll('input, select');
        inputs.forEach(input => {
            const name = input.getAttribute('name');
            if (name) {
                input.setAttribute('name', name.replace(/\[\d+]/, `[${this.transactionCount}]`));
                input.value = '';
            }
        });

        // Add the new transaction to the container
        container.appendChild(newTransaction);

        this.transactionCount++;
    }

    disconnect() {
        // Clean up any chart or event listeners
        if (this.chart) {
            this.chart.destroy();
        }
    }
}