import {Controller} from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
    static targets = [
        "messagesContainer",
        "loadingMessage",
        "queryInput",
        "visualizationArea",
        "visualizationTitle",
        "forecastChart",
        "trendsChart",
        "budgetChart",
        "emptyVisualization"
    ]

    charts = {}

    connect() {
        console.log("Fin Assistant controller connected")
        this.scrollToBottom()
    }

    disconnect() {
        // Destroy any charts when the controller disconnects
        Object.values(this.charts).forEach(chart => {
            if (chart) chart.destroy()
        })
    }

    // Submit a query to the assistant
    async submitQuery(event) {
        event.preventDefault()

        const query = this.queryInputTarget.value.trim()
        if (!query) return

        // Add a user message to the chat
        this.addUserMessage(query)

        // Show loading indicator
        this.loadingMessageTarget.classList.remove("hidden")

        // Scroll to bottom to show loading indicator
        this.scrollToBottom()

        // Clear input
        this.queryInputTarget.value = ""

        try {
            // Send the query to the server
            const response = await fetch("/fin/query", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "X-CSRF-Token": this.getCSRFToken()
                },
                body: JSON.stringify({ query })
            })

            const data = await response.json()

            if (response.ok) {
                // Hide loading indicator
                this.loadingMessageTarget.classList.add("hidden")

                // Add an assistant response to the chat
                this.addAssistantMessage(data.message)

                // Process any actions
                if (data.actions && data.actions.length > 0) {
                    this.processActions(data.actions)
                }
            } else {
                // Hide loading indicator
                this.loadingMessageTarget.classList.add("hidden")

                // Show an error message
                this.addAssistantMessage(`Sorry, I encountered an error: ${data.error || "Unknown error"}`)
            }
        } catch (error) {
            console.error("Error querying Fin:", error)

            // Hide loading indicator
            this.loadingMessageTarget.classList.add("hidden")

            // Show an error message
            this.addAssistantMessage("Sorry, I'm having trouble connecting to the server. Please try again.")
        }
    }

    // Handle Enter key in the input field
    handleEnter(event) {
        // Submit on Enter (without Shift)
        if (event.key === "Enter" && !event.shiftKey) {
            event.preventDefault()
            this.submitQuery(event).then(r => r)
        }
    }

    // Fill the input field with a sample query
    fillSampleQuery(event) {
        this.queryInputTarget.value = event.currentTarget.dataset.query || event.currentTarget.textContent.trim()
        this.queryInputTarget.focus()
    }

    // Add a user message to the chat
    addUserMessage(message) {
        const userMessage = `
      <div class="flex items-start justify-end mb-4">
        <div class="bg-green-100 rounded-l-lg rounded-br-lg p-4 max-w-xl">
          <p class="text-gray-800">${this.escapeHTML(message)}</p>
        </div>
        <div class="flex-shrink-0 ml-3">
          <div class="flex items-center justify-center h-10 w-10 rounded-full bg-green-600 text-white">
            <i class="bi bi-person-fill"></i>
          </div>
        </div>
      </div>
    `

        this.messagesContainerTarget.insertAdjacentHTML("beforeend", userMessage)
        this.scrollToBottom()
    }

    // Add an assistant message to the chat
    addAssistantMessage(message, messageId = null) {
        // Generate a temporary ID if none is provided
        const id = messageId || `temp-msg-${Date.now()}`;

        const assistantMessage = `
    <div class="flex items-start mb-4" id="message-${id}">
      <div class="flex-shrink-0 mr-3">
        <div class="flex items-center justify-center h-10 w-10 rounded-full bg-blue-600 text-white">
          <i class="bi bi-robot"></i>
        </div>
      </div>
      <div class="bg-blue-100 rounded-r-lg rounded-bl-lg p-4 max-w-xl">
        <p class="text-gray-800 whitespace-pre-wrap">${this.formatMessage(message)}</p>
        
        <!-- Feedback Component -->
        <div class="message-feedback mt-3 pt-2 border-t border-blue-200">
          <p class="text-xs text-gray-600 mb-2">Was this response helpful?</p>
          <div class="flex items-center space-x-3">
            <button 
              class="text-xs px-2 py-1 rounded-full bg-blue-50 text-blue-600 hover:bg-blue-600 hover:text-white transition-colors"
              data-action="click->fin-assistant#provideFeedback"
              data-fin-assistant-message-id="${id}"
              data-fin-assistant-feedback="helpful"
              data-fin-assistant-rating="5">
              Very Helpful
            </button>
            <button 
              class="text-xs px-2 py-1 rounded-full bg-blue-50 text-blue-600 hover:bg-blue-600 hover:text-white transition-colors"
              data-action="click->fin-assistant#provideFeedback"
              data-fin-assistant-message-id="${id}"
              data-fin-assistant-feedback="somewhat"
              data-fin-assistant-rating="3">
              Somewhat Helpful
            </button>
            <button 
              class="text-xs px-2 py-1 rounded-full bg-blue-50 text-blue-600 hover:bg-blue-600 hover:text-white transition-colors"
              data-action="click->fin-assistant#provideFeedback"
              data-fin-assistant-message-id="${id}"
              data-fin-assistant-feedback="unhelpful"
              data-fin-assistant-rating="1">
              Not Helpful
            </button>
          </div>
        </div>
      </div>
    </div>
  `;

        this.messagesContainerTarget.insertAdjacentHTML("beforeend", assistantMessage);
        this.scrollToBottom();
    }

    provideFeedback(event) {
        const messageId = event.currentTarget.dataset.finAssistantMessageId;
        const feedback = event.currentTarget.dataset.finAssistantFeedback;
        const rating = parseInt(event.currentTarget.dataset.finAssistantRating);

        // Find the feedback container for this message
        const messageEl = document.getElementById(`message-${messageId}`);
        if (!messageEl) return;

        const feedbackContainer = messageEl.querySelector('.message-feedback');
        if (!feedbackContainer) return;

        // Update UI to show the feedback was received
        feedbackContainer.innerHTML = `
    <p class="text-xs text-green-600 flex items-center">
      <i class="bi bi-check-circle mr-1"></i>
      Thank you for your feedback!
    </p>
  `;

        // Send the feedback to the server
        fetch("/fin/feedback", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "X-CSRF-Token": this.getCSRFToken()
            },
            body: JSON.stringify({
                message_id: messageId,
                feedback: feedback,
                rating: rating
            })
        })
            .then(response => {
                if (!response.ok) {
                    console.error("Failed to save feedback");
                    feedbackContainer.innerHTML = `
        <p class="text-xs text-red-600">
          Failed to save feedback. Please try again.
        </p>
      `;
                }
            })
            .catch(error => {
                console.error("Error saving feedback:", error);
                feedbackContainer.innerHTML = `
      <p class="text-xs text-red-600">
        Failed to save feedback. Please try again.
      </p>
    `;
            });
    }

    // Process actions from the assistant
    processActions(actions) {
        // Hide an empty visualization message
        this.emptyVisualizationTarget.classList.add("hidden")

        actions.forEach(action => {
            if (action.type === "redirect") {
                // Save the URL and show a message with a link
                const redirectAction = `
          <div class="flex items-start mb-4">
            <div class="flex-shrink-0 mr-3">
              <div class="flex items-center justify-center h-10 w-10 rounded-full bg-blue-600 text-white">
                <i class="bi bi-robot"></i>
              </div>
            </div>
            <div class="bg-blue-100 rounded-r-lg rounded-bl-lg p-4 max-w-xl">
              <p class="text-gray-800">I've created a forecast for you. Would you like to view it?</p>
              <a href="${action.url}" class="mt-2 inline-flex items-center px-3 py-1.5 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700">
                <i class="bi bi-graph-up mr-1"></i> View Forecast
              </a>
            </div>
          </div>
        `
                this.messagesContainerTarget.insertAdjacentHTML("beforeend", redirectAction)

            } else if (action.type === "update_chart") {
                this.updateChart(action.chart_id, action.data)
            }
        })

        this.scrollToBottom()
    }

    // Update a chart with new data
    updateChart(chartId, data) {
        // Clear old charts
        Object.values(this.charts).forEach(chart => {
            if (chart) chart.destroy()
        })

        // Hide all chart containers
        this.forecastChartTarget.classList.add("hidden")
        this.trendsChartTarget.classList.add("hidden")
        this.budgetChartTarget.classList.add("hidden")

        let chartTarget
        let chartOptions

        if (chartId === "forecast_chart") {
            chartTarget = this.forecastChartTarget
            this.visualizationTitleTarget.textContent = "Cash Flow Forecast"
            chartOptions = this.createForecastChartOptions(data)
        } else if (chartId === "trends_chart") {
            chartTarget = this.trendsChartTarget
            this.visualizationTitleTarget.textContent = "Spending Trends Analysis"
            chartOptions = this.createTrendsChartOptions(data)
        } else if (chartId === "budget_chart") {
            chartTarget = this.budgetChartTarget
            this.visualizationTitleTarget.textContent = "Budget Recommendations"
            chartOptions = this.createBudgetChartOptions(data)
        }

        if (chartTarget && chartOptions) {
            chartTarget.classList.remove("hidden")
            this.charts[chartId] = new ApexCharts(chartTarget, chartOptions)
            this.charts[chartId].render()
        }
    }

    // Create options for the forecast chart
    createForecastChartOptions(data) {
        const dates = data.forecast.map(item => item.date)
        const balances = data.forecast.map(item => item.balance)
        const incomes = data.forecast.map(item => item.income)
        const expenses = data.forecast.map(item => item.expenses)

        return {
            series: [
                {
                    name: 'Balance',
                    data: balances,
                    type: 'line'
                },
                {
                    name: 'Income',
                    data: incomes,
                    type: 'column'
                },
                {
                    name: 'Expenses',
                    data: expenses.map(v => -Math.abs(v)), // Make expenses negative
                    type: 'column'
                }
            ],
            chart: {
                height: 350,
                toolbar: {
                    show: true
                }
            },
            plotOptions: {
                bar: {
                    columnWidth: '60%',
                },
            },
            xaxis: {
                categories: dates,
                labels: {
                    rotate: -45,
                    style: {
                        fontSize: '10px'
                    }
                }
            },
            yaxis: {
                title: {
                    text: 'Amount'
                },
                labels: {
                    formatter: function(value) {
                        return '$' + Math.abs(value).toFixed(0);
                    }
                }
            },
            stroke: {
                curve: 'smooth',
                width: [4, 0, 0]  // Line width for balance, no line for columns
            },
            colors: ['#3b82f6', '#10b981', '#ef4444'], // Blue, Green, Red
            dataLabels: {
                enabled: false
            },
            legend: {
                position: 'top'
            }
        }
    }

    // Create options for the trends chart (simplified example)
    createTrendsChartOptions(data) {
        // This would be customized based on your actual data structure
        return {
            series: [{
                name: 'Spending',
                data: [30, 40, 35, 50, 49, 60, 70, 91, 125]
            }],
            chart: {
                height: 350,
                type: 'line',
            },
            xaxis: {
                categories: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'],
            }
        }
    }

    // Create options for the budget chart (simplified example)
    createBudgetChartOptions(data) {
        // This would be customized based on your actual data structure
        return {
            series: [{
                name: 'Budget',
                data: [44, 55, 41, 37, 22, 43, 21]
            }, {
                name: 'Actual',
                data: [53, 32, 33, 52, 13, 43, 32]
            }],
            chart: {
                type: 'bar',
                height: 350
            },
            plotOptions: {
                bar: {
                    horizontal: false,
                    columnWidth: '55%',
                },
            },
            dataLabels: {
                enabled: false
            },
            xaxis: {
                categories: ['Groceries', 'Dining', 'Shopping', 'Transport', 'Entertainment', 'Bills', 'Others'],
            }
        }
    }

    // Format the message text (handle markdown, links, etc.)
    formatMessage(message) {
        let formatted = this.escapeHTML(message)

        // Convert Markdown-style links: [text](url)
        formatted = formatted.replace(/\[([^\]]+)]\(([^)]+)\)/g, '<a href="$2" class="text-blue-600 hover:underline" target="_blank">$1</a>')

        // Convert Markdown-style bold: **text**
        formatted = formatted.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')

        // Convert Markdown-style italic: *text*
        formatted = formatted.replace(/\*([^*]+)\*/g, '<em>$1</em>')

        return formatted
    }

    // Safely escape HTML to prevent XSS
    escapeHTML(text) {
        const div = document.createElement('div')
        div.textContent = text
        return div.innerHTML
    }

    // Scroll the message container to the bottom
    scrollToBottom() {
        this.messagesContainerTarget.scrollTop = this.messagesContainerTarget.scrollHeight
    }

    // Get CSRF token for form submissions
    getCSRFToken() {
        return document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    }}