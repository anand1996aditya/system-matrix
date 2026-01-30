// Optimized File Browser - Standalone JavaScript Module
// Handles all file browsing operations with minimal code

const FileBrowser = {
    currentPath: null,
    cache: new Map(),

    // File type icons mapping
    icons: {
        dir: '📁',
        txt: '📄', md: '📝', pdf: '📕', doc: '📘', docx: '📘',
        xls: '📊', xlsx: '📊', jpg: '🖼️', jpeg: '🖼️', png: '🖼️',
        gif: '🖼️', svg: '🖼️', mp4: '🎬', mov: '🎬', avi: '🎬',
        mkv: '🎬', mp3: '🎵', wav: '🎵', flac: '🎵', zip: '📦',
        rar: '📦', '7z': '📦', tar: '📦', gz: '📦', js: '📜',
        py: '🐍', java: '☕', cpp: '⚙️', c: '⚙️', html: '🌐',
        css: '🎨', json: '📋', xml: '📋', exe: '⚡', app: '⚡',
        dmg: '💿', iso: '💿', default: '📄'
    },

    drives: [
        {name: 'Internal (Home)', path: '/Users/aditya'},
        {name: 'Data', path: '/Volumes/Data'},
        {name: 'EVM', path: '/Volumes/EVM'},
        {name: 'Extreme SSD', path: '/Volumes/Extreme SSD'}
    ],

    // Fetch with credentials (for auth)
    async fetch(url) {
        const response = await fetch(url, {
            credentials: 'same-origin',
            headers: {'Cache-Control': 'no-cache'}
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return response.json();
    },

    // Format bytes to human readable
    formatBytes(bytes) {
        if (!bytes) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return `${(bytes / Math.pow(k, i)).toFixed(2)} ${sizes[i]}`;
    },

    // Get file icon
    getIcon(name, isDir) {
        if (isDir) return this.icons.dir;
        const ext = name.split('.').pop().toLowerCase();
        return this.icons[ext] || this.icons.default;
    },

    // Build breadcrumb navigation
    buildBreadcrumb(path) {
        const parts = path.split('/').filter(Boolean);
        return parts.map((part, i) => {
            const p = '/' + parts.slice(0, i + 1).join('/');
            return i === parts.length - 1
                ? `<span style="color:#00FFFF">${part}</span>`
                : `<a href="#" onclick="FileBrowser.browse('${p}');return false" style="color:#00FF41;text-decoration:none">${part}</a>`;
        }).join(' <span style="color:#00AA33">/</span> ');
    },

    // Show loading state
    loading(msg = 'Loading...') {
        document.getElementById('file-browser-content').innerHTML =
            `<div style="text-align:center;padding:30px;color:#00FF41">${msg}</div>`;
    },

    // Show error state
    error(msg) {
        document.getElementById('file-browser-content').innerHTML =
            `<div style="text-align:center;padding:20px;color:#FF9900">⚠ ${msg}<br>
            <button class="service-btn" onclick="FileBrowser.showDrives()" style="margin-top:10px">🏠 DRIVES</button></div>`;
    },

    // Load and show drives
    async showDrives() {
        this.currentPath = null;
        this.loading('Scanning drives...');

        try {
            const data = await this.fetch('/api/files/drives');
            const html = data.drives.map(d => `
                <div class="service-item" style="${d.available ? '' : 'opacity:0.5'}">
                    <div class="service-name">
                        <span>${d.available ? '💾' : '❌'} ${d.name}</span>
                        <span class="status-dot status-${d.available ? 'running' : 'stopped'}"></span>
                    </div>
                    <div class="service-details" style="font-size:0.75em;color:#00AA33">${d.path}</div>
                    ${d.available ?
                        `<button class="service-btn" onclick="FileBrowser.browse('${d.path}')" style="width:100%;background:rgba(0,100,200,0.4);margin-top:6px">📂 BROWSE</button>` :
                        `<div style="color:#0099FF;font-size:0.75em;margin-top:4px;text-align:center">Not mounted</div>`
                    }
                </div>
            `).join('');

            document.getElementById('file-browser-content').innerHTML = html;
        } catch (err) {
            this.error('Failed to load drives: ' + err.message);
        }
    },

    // Browse directory
    async browse(path) {
        this.currentPath = path;
        this.loading('Loading directory...');

        try {
            const data = await this.fetch(`/api/files/list?path=${encodeURIComponent(path)}`);

            // Build file list
            const items = data.items.map(item => {
                const icon = this.getIcon(item.name, item.is_directory);
                const size = item.is_directory ? '-' : this.formatBytes(item.size);
                const date = new Date(item.modified).toLocaleString();
                const action = item.is_directory ?
                    `FileBrowser.browse('${item.path}')` :
                    `FileBrowser.download('${item.path}','${item.name}')`;

                return `
                    <div class="metric" style="padding:8px;border-bottom:1px solid #003300;cursor:pointer;transition:background 0.2s"
                         onmouseover="this.style.background='rgba(0,80,0,0.3)'"
                         onmouseout="this.style.background='transparent'"
                         onclick="${action}">
                        <div style="display:flex;align-items:center;gap:10px">
                            <span style="font-size:1.2em">${icon}</span>
                            <div style="flex:1">
                                <div style="color:#00FF41;font-weight:600">${item.name}</div>
                                <div style="color:#00AA33;font-size:0.75em">${size} • ${date}</div>
                            </div>
                        </div>
                    </div>
                `;
            }).join('') || '<div style="text-align:center;padding:20px;color:#00AA33;font-style:italic">Empty directory</div>';

            // Determine parent path
            const parent = path.substring(0, path.lastIndexOf('/')) || '/';
            const canGoBack = this.drives.some(d => path !== d.path && path.startsWith(d.path));

            // Build UI
            document.getElementById('file-browser-content').innerHTML = `
                <div style="margin-bottom:10px;padding:8px;background:rgba(0,50,0,0.4);border:1px solid #00AA33;border-radius:3px">
                    <div style="color:#00FFFF;font-size:0.85em;margin-bottom:4px">📍 ${this.buildBreadcrumb(path)}</div>
                    <div style="margin-top:8px;display:flex;gap:8px">
                        ${canGoBack ? `<button class="service-btn" onclick="FileBrowser.browse('${parent}')" style="flex:0 0 auto;background:rgba(100,0,100,0.4)">⬅ BACK</button>` : ''}
                        <button class="service-btn" onclick="FileBrowser.showDrives()" style="flex:0 0 auto;background:rgba(100,100,0,0.4)">🏠 DRIVES</button>
                        <button class="service-btn" onclick="FileBrowser.refresh()" style="flex:0 0 auto;background:rgba(0,100,100,0.4)">🔄 REFRESH</button>
                    </div>
                </div>
                <div style="max-height:400px;overflow-y:auto;border:1px solid #00AA33;border-radius:3px;background:rgba(0,20,0,0.3)">
                    ${items}
                </div>
            `;
        } catch (err) {
            this.error('Failed to load directory: ' + err.message);
        }
    },

    // Refresh current view
    refresh() {
        this.currentPath ? this.browse(this.currentPath) : this.showDrives();
    },

    // Download file
    download(path, name) {
        const url = `/api/files/download?path=${encodeURIComponent(path)}`;
        const a = document.createElement('a');
        a.href = url;
        a.download = name;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    },

    // Initialize
    init() {
        this.showDrives();
    }
};

// Auto-initialize when called
if (typeof window !== 'undefined') {
    window.FileBrowser = FileBrowser;
}
