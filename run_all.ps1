# PowerShell launcher for Distributed Online Exam System (Windows)
# Usage:
#   Right-click → Run with PowerShell (or)
#   powershell.exe -ExecutionPolicy Bypass -File .\run_all.ps1

param(
    [string]$ProjectRoot = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$PythonExe = "C:\\Program Files\\Python310\\python.exe"
)

function Write-Info($msg) {
    Write-Host "[INFO] $msg" -ForegroundColor Cyan
}

Set-Location $ProjectRoot
Write-Info "Project root: $ProjectRoot"

# 1) Ensure venv exists
if (-not (Test-Path $PythonExe)) {
    Write-Host "[ERROR] Python not found at: $PythonExe" -ForegroundColor Red
    Write-Host "        Update -PythonExe parameter to your Python path." -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path ".\.venv")) {
    Write-Info "Creating virtual environment with: $PythonExe (.venv)"
    & "$PythonExe" -m venv .venv
}

$VenvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $VenvPython)) {
    Write-Host "[ERROR] venv python not found at: $VenvPython" -ForegroundColor Red
    exit 1
}

# 2) Install dependencies
Write-Info "Upgrading pip/setuptools/wheel"
& "$VenvPython" -m pip install --upgrade pip setuptools wheel | Out-Null

Write-Info "Installing project dependencies"
& "$VenvPython" -m pip install grpcio==1.62.2 grpcio-tools==1.62.2 protobuf==4.25.3 fastapi==0.115.0 uvicorn[standard]==0.30.6 websockets==12.0 pandas==2.2.2 openpyxl==3.1.5 | Out-Null

# 3) Generate gRPC stubs if missing
if (-not (Test-Path ".\unified_exam_system_pb2.py") -or -not (Test-Path ".\unified_exam_system_pb2_grpc.py")) {
    Write-Info "Generating gRPC stubs from unified_exam_system.proto"
    & "$VenvPython" -m grpc_tools.protoc --python_out=. --grpc_python_out=. --proto_path=. unified_exam_system.proto
}

# 4) Ensure data/static/result directories
Write-Info "Ensuring directories exist (exam_data, exam_data_backup, static, Results)"
New-Item -ItemType Directory -Force -Path ".\exam_data" | Out-Null
New-Item -ItemType Directory -Force -Path ".\exam_data_backup" | Out-Null
New-Item -ItemType Directory -Force -Path ".\static" | Out-Null
New-Item -ItemType Directory -Force -Path ".\Results" | Out-Null

# Helper to spawn new terminal window for each service
function Start-ServiceWindow($title, $command) {
    $psCmd = "cd `"$ProjectRoot`"; & `"$VenvPython`" $command"
    Start-Process -FilePath "powershell" -ArgumentList "-NoExit","-Command",$psCmd -WindowStyle Normal
    Write-Info "Launched: $title"
}

Write-Info "Starting services in separate windows (order matters)"

# 5) Start services
Start-ServiceWindow "Ricart-Agrawala Service (50052)" "ricart_agrawala_service.py"
Start-Sleep -Seconds 1

Start-ServiceWindow "Consistency Service (50053)" "consistency_service.py"
Start-Sleep -Seconds 1

Start-ServiceWindow "Load Balancer + Backup (50055/50056)" "load_balancer_service.py"
Start-Sleep -Seconds 1

Start-ServiceWindow "Main Server (50050)" "main_server.py"
Start-Sleep -Seconds 1

# Web server defaults to 127.0.0.1:8888
Start-ServiceWindow "Web Server (http://127.0.0.1:8888)" "web_server.py"

Write-Info "All service windows launched. Open http://127.0.0.1:8888 or http://127.0.0.1:8888/try"

