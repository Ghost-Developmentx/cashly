module.exports = {
    content: [
        './app/views/**/*.{html,html.erb,erb}',
        './app/helpers/**/*.rb',
        './app/javascript/**/*.js',
        './app/assets/stylesheets/**/*.css',
        './app/assets/stylesheets/**/*.scss',
    ],
    safelist: [
        // Bootstrap classes you want to preserve during the transition
        {
            pattern: /^(navbar|nav|dropdown|btn|alert|card|badge|container|row|col|modal|form|text|bg|m|p|d|flex|justify|align|shadow|border|rounded)/,
        }
    ],
    theme: {
        extend: {},
    },
    plugins: [],
    // This is important - ensures Tailwind doesn't try to override elements already styled by Bootstrap
    corePlugins: {
        preflight: false,
    }
}