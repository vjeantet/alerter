import AppKit

let notificationManager = NotificationManager.shared

signal(SIGTERM) { _ in
    notificationManager.bye()
    exit(EXIT_FAILURE)
}

signal(SIGINT) { _ in
    notificationManager.bye()
    exit(EXIT_FAILURE)
}

AlerterCommand.main()
