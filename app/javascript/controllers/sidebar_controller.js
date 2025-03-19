// app/javascript/controllers/sidebar_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = [
        "sidebar",
        "collapsedSidebar",
        "content",
        "collapseIcon",
        "collapseText"
    ]

    connect() {
        // Check if the sidebar state is saved in localStorage
        const sidebarCollapsed = localStorage.getItem('sidebarCollapsed') === 'true'

        // Set the initial state based on saved preference or default to expand
        if (sidebarCollapsed) {
            this.collapse()
        } else {
            this.expand()
        }

        // Auto-collapse on small screens
        this.handleResponsiveLayout()

        // Add resize listener for responsive behavior
        window.addEventListener('resize', this.handleResponsiveLayout.bind(this))
    }

    disconnect() {
        // Remove event listener when controller is disconnected
        window.removeEventListener('resize', this.handleResponsiveLayout.bind(this))
    }

    // Toggle between expanded and collapsed states
    toggle() {
        const sidebarCollapsed = this.sidebarTarget.classList.contains('hidden')

        if (sidebarCollapsed) {
            this.expand()
        } else {
            this.collapse()
        }
    }

    // Toggle sidebar collapse/expand explicitly
    toggleCollapse() {
        const sidebarCollapsed = this.sidebarTarget.classList.contains('hidden')

        if (sidebarCollapsed) {
            this.expand()
        } else {
            this.collapse()
        }
    }

    // Expand the sidebar
    expand() {
        this.sidebarTarget.classList.remove('hidden')
        this.collapsedSidebarTarget.classList.add('hidden')
        this.contentTarget.classList.remove('ml-16')
        this.contentTarget.classList.add('ml-64')

        // Update icon and text if targets exist
        if (this.hasCollapseIconTarget) {
            this.collapseIconTarget.classList.remove('bi-chevron-double-right')
            this.collapseIconTarget.classList.add('bi-chevron-double-left')
        }

        if (this.hasCollapseTextTarget) {
            this.collapseTextTarget.textContent = 'Collapse Sidebar'
        }

        // Save state to localStorage
        localStorage.setItem('sidebarCollapsed', 'false')
    }

    // Collapse the sidebar
    collapse() {
        this.sidebarTarget.classList.add('hidden')
        this.collapsedSidebarTarget.classList.remove('hidden')
        this.contentTarget.classList.remove('ml-64')
        this.contentTarget.classList.add('ml-16')

        // Update icon and text if targets exist
        if (this.hasCollapseIconTarget) {
            this.collapseIconTarget.classList.remove('bi-chevron-double-left')
            this.collapseIconTarget.classList.add('bi-chevron-double-right')
        }

        if (this.hasCollapseTextTarget) {
            this.collapseTextTarget.textContent = 'Expand Sidebar'
        }

        // Save state to localStorage
        localStorage.setItem('sidebarCollapsed', 'true')
    }

    // Handle responsive layout changes
    handleResponsiveLayout() {
        if (window.innerWidth < 768) {
            // On mobile/small screens, collapse by default
            this.collapse()
        } else {
            // On larger screens, respect user preference
            const sidebarCollapsed = localStorage.getItem('sidebarCollapsed') === 'true'
            if (sidebarCollapsed) {
                this.collapse()
            } else {
                this.expand()
            }
        }
    }
}