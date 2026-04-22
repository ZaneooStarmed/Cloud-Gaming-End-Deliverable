To set up this Cloud Gaming prototype, you must follow these instructions.

1. Launch the Sunshine.exe on the Host Machine that will emulate the game. Once done the user must create a username and password for access otherwise they won't have access to the network and security configurations.

2. Install the Desktop version of Docker to be able to access the Docker.

3. Launch "docker-compose up --build" in the terminal of the Cloud Gaming Folder.

4. In sunshine, set the location to launch the game to the shortcut of New Super Mario Bros Wii in the Dolphin Folder.(Wii ROM will not be provided, User must provide their own.)

5. Instal Moonlight on the client device and connected via the pinlock on sunshine for security.

6. Launch "agent.ps1" from the host-agent folder before launching the emulator through Moonlight.

7. Log into the local host of Grafana with the credentials:
username:admin
password:cloudgaming

8.Select the New Super Mario Bros Wii Game from Moonlight to begin the simulation.

9. When applying latency unless, on the host machine set it up before running Moonlight game.

10.Clumsy commands
filtering:outbound and loopback
presets:localhost ipv4 all
lag : on

11. To stop the project, in the terminal enter "docker-compose down" to remove any changes.

