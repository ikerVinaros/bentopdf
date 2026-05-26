import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';
import os from 'os';

const LOG_FILE = path.join(process.cwd(), 'resource-monitor.log');
const INTERVAL = 1000; // 1 second

// Get all Node/Vite processes
function getNodeProcesses() {
  return new Promise((resolve, reject) => {
    const processes = [];
    const child = spawn('ps', ['aux']);
    
    let stdout = '';
    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });
    
    child.on('close', () => {
      const lines = stdout.split('\n');
      for (const line of lines) {
        if (line.includes('vite') || line.includes('node')) {
          const parts = line.trim().split(/\s+/);
          if (parts.length >= 2) {
            processes.push({
              pid: parseInt(parts[1]),
              fullLine: line
            });
          }
        }
      }
      resolve(processes);
    });
    
    child.on('error', reject);
  });
}

// Get CPU and memory usage for a PID
function getProcessStats(pid) {
  return new Promise((resolve) => {
    const child = spawn('ps', ['-p', pid.toString(), '-o', '%cpu,%mem,rsz']);
    
    let stdout = '';
    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });
    
    child.on('close', () => {
      const lines = stdout.trim().split('\n');
      if (lines.length >= 2) {
        const parts = lines[1].trim().split(/\s+/);
        resolve({
          cpu: parseFloat(parts[0]) || 0,
          mem: parseFloat(parts[1]) || 0,
          rss: parseInt(parts[2]) || 0
        });
      } else {
        resolve(null);
      }
    });
    
    child.on('error', () => resolve(null));
  });
}

// Format bytes to human readable
function formatBytes(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(2) + ' KB';
  if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
  return (bytes / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
}

// Main monitoring function
async function monitorResources() {
  const timestamp = new Date().toISOString();
  const systemMem = os.totalmem();
  const freeMem = os.freemem();
  const usedMem = systemMem - freeMem;
  
  // Get server load
  const load = os.loadavg();
  
  // Try to find Vite/Node process
  const nodeProcs = await getNodeProcesses();
  
  let logEntry = `[${timestamp}] System Load: ${load[0].toFixed(2)}, ${load[1].toFixed(2)}, ${load[2].toFixed(2)} | RAM: ${formatBytes(usedMem)}/${formatBytes(systemMem)}`;
  
  if (nodeProcs.length > 0) {
    for (const proc of nodeProcs) {
      const stats = await getProcessStats(proc.pid);
      if (stats) {
        logEntry += ` | PID ${proc.pid}: CPU=${stats.cpu}%, MEM=${stats.mem}%, RSS=${formatBytes(stats.rss * 1024)}`;
      }
    }
  } else {
    logEntry += ' | No Node/Vite process found';
  }
  
  // Write to log file
  fs.appendFileSync(LOG_FILE, logEntry + '\n');
  console.log(logEntry);
}

// Check if process is running
async function checkProcessRunning() {
  const nodeProcs = await getNodeProcesses();
  return nodeProcs.length > 0;
}

// Main loop
async function main() {
  console.log(`Starting resource monitor...`);
  console.log(`Log file: ${LOG_FILE}`);
  
  // Clear previous log
  fs.writeFileSync(LOG_FILE, `# Resource Monitor Log - Started at ${new Date().toISOString()}\n`);
  
  let wasRunning = false;
  
  setInterval(async () => {
    const isRunning = await checkProcessRunning();
    
    if (isRunning && !wasRunning) {
      fs.appendFileSync(LOG_FILE, `\n# Process started at ${new Date().toISOString()}\n`);
      console.log('\n>>> Process detected! Starting monitoring...\n');
    } else if (!isRunning && wasRunning) {
      fs.appendFileSync(LOG_FILE, `\n# Process stopped at ${new Date().toISOString()}\n`);
      console.log('\n>>> Process stopped.\n');
    }
    
    if (isRunning) {
      await monitorResources();
    }
    
    wasRunning = isRunning;
  }, INTERVAL);
}

main().catch(console.error);
