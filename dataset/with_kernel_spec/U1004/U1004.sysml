package BroadcastAutomationSystem {
    private import ISQ::*;
    private import ScalarValues::*;

    item def MediaAsset {
        attribute assetId : String;
        attribute title : String;
    }
    item def Schedule {
        attribute playlistId : String;
    }
    item def Command {
        attribute commandType : String;
        attribute target : String;
    }
    item def VideoSignal;
    item def AudioSignal;
    item def ProgramFeed;
    item def TransmissionFeed;
    item def GraphicsOverlay {
        attribute overlayType : String;
        attribute position : String;
    }

    attribute def SystemTime;
    attribute def LoadPlaylist;
    attribute def StartSignal;
    attribute def ErrorSignal;
    attribute def FailoverComplete;
    attribute def BroadcastEnd;
    attribute def ResetSignal;

    action def monitorClock;
    action def loadSchedule;
    action def validatePlaylist;
    action def switchToPrimary;
    action def executePlaylist;
    action def triggerFailover;
    action def activateBackup;
    action def verifyBackupFeed;
    action def archiveLogs;
    action def clearErrors;

    part def SystemClock {
        port clockOut { out clock : SystemTime; }
    }

    part def PlayoutAutomation {
        port schedulePort { in schedule : Schedule; }
        port clockPort { in clock : SystemTime; }
        port commandPort { out command : Command; }
        port statusPort { in status : Command; in error : ErrorSignal; }

        exhibit state automationStates {
            entry; then idle;
            state idle {
                do action monitorClock;
            }
            accept LoadPlaylist via schedulePort
                do action loadSchedule
                then standby;
            state standby {
                do action validatePlaylist;
            }
            accept StartSignal
                do action switchToPrimary
                then active;
            state active {
                do action executePlaylist;
                do send new Command() to commandPort;
            }
            accept ErrorSignal via statusPort
                do action triggerFailover
                then emergency;
            state emergency {
                do action activateBackup;
                do send new Command() to commandPort;
            }
            accept FailoverComplete
                do action verifyBackupFeed
                then standby;
            accept BroadcastEnd
                do action archiveLogs
                then idle;
            accept ResetSignal
                do action clearErrors
                then idle;
        }
    }

    part def MediaServer {
        port commandPort { in command : Command; }
        port mediaOutPort { out video : VideoSignal; out audio : AudioSignal; }
        port statusPort { out status : Command; }
        item mediaLibrary : MediaAsset[0..*];
    }

    part def GraphicsEngine {
        port commandPort { in command : Command; }
        port graphicsOutPort { out overlay : GraphicsOverlay; }
        port statusPort { out status : Command; }
    }

    part def VideoRouter {
        port commandPort { in command : Command; }
        port primaryIn { in video : VideoSignal; in audio : AudioSignal; }
        port backupIn { in video : VideoSignal; in audio : AudioSignal; }
        port graphicsIn { in overlay : GraphicsOverlay; }
        port routerOut { out video : VideoSignal; out audio : AudioSignal; }
        port statusPort { out status : Command; }
    }

    part def MasterControl {
        port controlPort { in command : Command; }
        port primaryIn { in video : VideoSignal; in audio : AudioSignal; }
        port backupIn { in video : VideoSignal; in audio : AudioSignal; }
        port masterOut { out program : ProgramFeed; }
        port statusPort { out status : Command; }
        port failoverPort { out failover : ErrorSignal; }

        exhibit state masterStates {
            entry; then primary;
            state primary;
            accept ErrorSignal
                then backup;
            state backup;
            accept ResetSignal
                then primary;
        }
    }

    part def TransmissionEncoder {
        port controlPort { in command : Command; }
        port programIn { in program : ProgramFeed; }
        port transmitOut { out feed : TransmissionFeed; }
        port statusPort { out status : Command; }
    }

    part def BroadcastSystem {
        part playoutAutomation : PlayoutAutomation;
        part systemClock : SystemClock;
        part primaryServer : MediaServer;
        part backupServer : MediaServer;
        part graphicsEngine : GraphicsEngine;
        part videoRouter : VideoRouter;
        part masterControl : MasterControl;
        part transmissionEncoder : TransmissionEncoder;

        connect systemClock.clockOut to playoutAutomation.clockPort;

        connect playoutAutomation.commandPort to primaryServer.commandPort;
        connect playoutAutomation.commandPort to backupServer.commandPort;
        connect playoutAutomation.commandPort to graphicsEngine.commandPort;
        connect playoutAutomation.commandPort to videoRouter.commandPort;
        connect playoutAutomation.commandPort to masterControl.controlPort;
        connect playoutAutomation.commandPort to transmissionEncoder.controlPort;

        connect primaryServer.mediaOutPort to videoRouter.primaryIn;
        connect backupServer.mediaOutPort to videoRouter.backupIn;
        connect graphicsEngine.graphicsOutPort to videoRouter.graphicsIn;

        connect videoRouter.routerOut to masterControl.primaryIn;
        connect backupServer.mediaOutPort to masterControl.backupIn;

        connect masterControl.masterOut to transmissionEncoder.programIn;

        connect primaryServer.statusPort to playoutAutomation.statusPort;
        connect backupServer.statusPort to playoutAutomation.statusPort;
        connect graphicsEngine.statusPort to playoutAutomation.statusPort;
        connect videoRouter.statusPort to playoutAutomation.statusPort;
        connect masterControl.statusPort to playoutAutomation.statusPort;
        connect masterControl.failoverPort to playoutAutomation.statusPort;
        connect transmissionEncoder.statusPort to playoutAutomation.statusPort;
    }

    requirement def 'Continuous Broadcast' {
        doc "The system shall ensure continuous, frame-accurate, and compliant on-air delivery 24/7.";
    }

    requirement def 'Automated Failover' {
        doc "The system shall automatically switch to backup feeds within 2 seconds upon detection of a critical signal loss.";
    }

    requirement def 'Frame-Accurate Playout' {
        doc "The system shall execute schedule events with a timing accuracy of less than 1 frame.";
    }

    requirement def 'Quality Control Checkpoint' {
        doc "Master Control shall validate signal integrity before passing the feed to the transmission encoder.";
    }

    part broadcastSystem : BroadcastSystem;

    satisfy 'Continuous Broadcast' by broadcastSystem;
    satisfy 'Automated Failover' by broadcastSystem;
    satisfy 'Frame-Accurate Playout' by broadcastSystem;
    satisfy 'Quality Control Checkpoint' by broadcastSystem.masterControl;
}
