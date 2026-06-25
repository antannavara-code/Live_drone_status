import re

with open('lib/screens/dashboard_screen.dart', 'r') as f:
    content = f.read()

# Replace _buildDashboardContent signature and usage
content = content.replace(
    'Widget _buildDashboardContent(List<DroneStatus> drones, double width) {',
    'Widget _buildDashboardContent(List<DroneStatus> drones, double width) {'
)

