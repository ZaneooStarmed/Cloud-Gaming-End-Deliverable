const express = require('express');
const fs = require('fs');
const promClient = require('prom-client');
const app = express();
app.use(express.json());

// ── File paths (mounted from host via docker-compose volumes) ──
const STATUS_FILE  = '/logs/status.json';
const COMMAND_FILE = '/logs/command.txt';

// ── Helper: send command to host agent ───────────────────
function sendCommand(command) {
    try {
        fs.writeFileSync(COMMAND_FILE, command);
        console.log(`Command sent to host agent: ${command}`);
        return true;
    } catch (e) {
        console.error(`Failed to write command file: ${e.message}`);
        return false;
    }
}

// ── Helper: read status from host agent ──────────────────
function readStatus() {
    try {
        if (fs.existsSync(STATUS_FILE)) {
            const raw = fs.readFileSync(STATUS_FILE, 'utf8');
            return JSON.parse(raw);
        }
    } catch (e) {
        console.error(`Failed to read status file: ${e.message}`);
    }
    return {
        dolphin_running: false,
        cpu_usage: 0,
        memory_mb: 0,
        uptime_seconds: 0
    };
}

// ── Prometheus setup ──────────────────────────────────────
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const activeSessions = new promClient.Gauge({
    name: 'gaming_active_sessions',
    help: 'Number of active gaming sessions',
    registers: [register]
});

const sessionStartTotal = new promClient.Counter({
    name: 'gaming_session_starts_total',
    help: 'Total number of gaming sessions started',
    registers: [register]
});

const dolphinMemory = new promClient.Gauge({
    name: 'dolphin_memory_mb',
    help: 'Dolphin emulator memory usage in MB',
    registers: [register]
});

const dolphinCpu = new promClient.Gauge({
    name: 'dolphin_cpu_usage',
    help: 'Dolphin emulator CPU usage',
    registers: [register]
});

const dolphinUptime = new promClient.Gauge({
    name: 'dolphin_uptime_seconds',
    help: 'Dolphin emulator session uptime in seconds',
    registers: [register]
});

const sessionDuration = new promClient.Histogram({
    name: 'gaming_session_duration_seconds',
    help: 'Duration of gaming sessions in seconds',
    buckets: [30, 60, 300, 600, 1800, 3600],
    registers: [register]
    
});

// Sunshine gauges
const sunshineRunning = new promClient.Gauge({
    name: 'sunshine_running',
    help: 'Whether Sunshine is running 1 or 0',
    registers: [register]
});

const sunshineCpu = new promClient.Gauge({
    name: 'sunshine_cpu_usage',
    help: 'Sunshine CPU usage',
    registers: [register]
});

const sunshineMemory = new promClient.Gauge({
    name: 'sunshine_memory_mb',
    help: 'Sunshine memory usage in MB',
    registers: [register]
});

const sunshineUptime = new promClient.Gauge({
    name: 'sunshine_uptime_seconds',
    help: 'Sunshine server uptime in seconds',
    registers: [register]
});

// Total sessions gauge — reads from agent counter file
const totalSessionsGauge = new promClient.Gauge({
    name: 'gaming_total_sessions',
    help: 'Total gaming sessions ever recorded',
    registers: [register]
});

// Network metrics
const networkDownload = new promClient.Gauge({
    name: 'network_download_mbps',
    help: 'Network download speed in Mbps',
    registers: [register]
});

const networkUpload = new promClient.Gauge({
    name: 'network_upload_mbps',
    help: 'Network upload speed in Mbps',
    registers: [register]
});

const networkTotalReceived = new promClient.Gauge({
    name: 'network_total_received_mb',
    help: 'Total data received in MB',
    registers: [register]
});

const networkTotalSent = new promClient.Gauge({
    name: 'network_total_sent_mb',
    help: 'Total data sent in MB',
    registers: [register]
});

const clumsyRunning = new promClient.Gauge({
    name: 'clumsy_running',
    help: 'Whether Clumsy network simulator is active 1 or 0',
    registers: [register]
});


// ── Background poller — reads status file every 2 seconds ─
function pollMetrics() {
    const status = readStatus();

    // Dolphin metrics
    dolphinCpu.set(status.cpu_usage || 0);
    dolphinMemory.set(status.memory_mb || 0);
    dolphinUptime.set(status.uptime_seconds || 0);
    activeSessions.set(status.dolphin_running ? 1 : 0);

    // Sunshine metrics
    sunshineRunning.set(status.sunshine_running ? 1 : 0);
    sunshineCpu.set(status.sunshine_cpu || 0);
    sunshineMemory.set(status.sunshine_memory || 0);
    sunshineUptime.set(status.sunshine_uptime || 0);

    // Network metrics
    networkDownload.set(status.network_download_mbps || 0);
    networkUpload.set(status.network_upload_mbps || 0);
    networkTotalReceived.set(status.network_total_received_mb || 0);
    networkTotalSent.set(status.network_total_sent_mb || 0);
    clumsyRunning.set(status.clumsy_running ? 1 : 0);

    // Total sessions — read from persistent counter
    totalSessionsGauge.set(status.total_sessions || 0);
}

// Poll every 2 seconds
pollMetrics();
setInterval(pollMetrics, 2000);
console.log('Metrics polling started — reading host status every 2 seconds');

// ── Prometheus endpoint ───────────────────────────────────
app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
});

// ── Root page ─────────────────────────────────────────────
app.get('/', (req, res) => {
    res.json({
        name: 'Cloud Gaming Session Manager',
        status: 'running',
        version: '1.0.0',
        timestamp: new Date().toISOString(),
        endpoints: {
            health:       'GET  /health',
            sessionStart: 'POST /session/start',
            sessionStop:  'POST /session/stop',
            metrics:      'GET  /metrics/session',
            prometheus:   'GET  /metrics'
        }
    });
});

// ── Health check ──────────────────────────────────────────
app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        uptime: process.uptime() + ' seconds'
    });
});

// ── Start gaming session ──────────────────────────────────
let sessionStartTime = null;

app.post('/session/start', (req, res) => {
    const { game = 'default' } = req.body;
    const sent = sendCommand('START');

    if (sent) {
        sessionStartTotal.inc();
        sessionStartTime = Date.now();
        res.json({
            status: 'session started',
            game,
            message: 'Command sent to host agent — Dolphin launching on host',
            timestamp: new Date().toISOString()
        });
    } else {
        res.status(500).json({
            status: 'error',
            message: 'Failed to send command to host agent',
            timestamp: new Date().toISOString()
        });
    }
});

// ── Stop gaming session ───────────────────────────────────
app.post('/session/stop', (req, res) => {
    const sent = sendCommand('STOP');

    if (sessionStartTime) {
        const duration = (Date.now() - sessionStartTime) / 1000;
        sessionDuration.observe(duration);
        sessionStartTime = null;
    }

    if (sent) {
        res.json({
            status: 'session stopped',
            message: 'Command sent to host agent — Dolphin closing on host',
            timestamp: new Date().toISOString()
        });
    } else {
        res.status(500).json({
            status: 'error',
            message: 'Failed to send stop command to host agent',
            timestamp: new Date().toISOString()
        });
    }
});

// ── Session metrics ───────────────────────────────────────
app.get('/metrics/session', (req, res) => {
    const status = readStatus();
    res.json({
        dolphin_running: status.dolphin_running,
        data: status,
        timestamp: new Date().toISOString()
    });
});

// ── 404 handler ───────────────────────────────────────────
app.use((req, res) => {
    res.status(404).json({
        error: 'Route not found',
        available_routes: [
            'GET  /',
            'GET  /health',
            'GET  /metrics',
            'GET  /metrics/session',
            'POST /session/start',
            'POST /session/stop'
        ]
    });
});

// ── Start server ──────────────────────────────────────────
app.listen(3000, '0.0.0.0', () => {
    console.log('Session Manager running on port 3000');
});