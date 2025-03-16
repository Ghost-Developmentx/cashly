// app/javascript/controllers/reconciliation_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["differenceAmount", "progressBar", "progressPercentage", "reconciledCount", "unreconciledCount"]

    connect() {
        console.log("Reconciliation controller connected")
    }

    // We can keep this method for displaying messages from JavaScript if needed
    showMessage(message, type) {
        // Create a notification element
        const notification = document.createElement('div')
        notification.className = `fixed top-4 right-4 z-50 p-4 rounded-md ${
            type === 'success' ? 'bg-green-100 border border-green-400 text-green-700' : 'bg-red-100 border border-red-400 text-red-700'
        }`

        notification.innerHTML = `
      <div class="flex">
        <div class="flex-shrink-0">
          ${
            type === 'success'
                ? '<svg class="h-5 w-5 text-green-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" /></svg>'
                : '<svg class="h-5 w-5 text-red-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" /></svg>'
        }
        </div>
        <div class="ml-3">
          <p class="text-sm">${message}</p>
        </div>
      </div>
    `

        // Append to body
        document.body.appendChild(notification)

        // Remove after 3 seconds
        setTimeout(() => {
            notification.remove()
        }, 3000)
    }
}