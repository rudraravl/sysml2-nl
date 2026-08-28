package FarmWiseAutonomousWeederModel {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SI::*;

    item def Image {
        attribute resolution : Integer;
        attribute timestamp : TimeValue;
    }
    item def GPSPosition {
        attribute latitude : Real;
        attribute longitude : Real;
    }
    item def WeedTarget {
        item position : GPSPosition;
        attribute confidence : Real;
    }
    item def DriveCommand {
        attribute speed : SpeedValue;
        attribute heading : Real;
    }
    item def WeederCommand {
        attribute deploy : Boolean;
        attribute depth : LengthValue;
    }
    item def ElectricalPower {
        attribute power : PowerValue;
    }

    action def CaptureImage { out image : Image; }
    action def ProcessImage { in image : Image; out target : WeedTarget; }
    action def Navigate { out position : GPSPosition; }
    action def DriveAction { in command : DriveCommand; }
    action def DeployWeeder { in command : WeederCommand; }
    action def RetractWeeder;
    action def MonitorBattery { out charge : EnergyValue; }
    action def CoordinateSystem {
        in target : WeedTarget;
        in position : GPSPosition;
        out driveCmd : DriveCommand;
        out weederCmd : WeederCommand;
    }

    attribute def StartSignal;
    attribute def ImageCaptured;
    attribute def WeedDetected;
    attribute def LocationReached;
    attribute def WeedRemoved;
    attribute def Docked;
    attribute def ChargeComplete;
    attribute def BatteryLow;

    state def WeederStates {
        entry action initial;
        transition initial then idle;
        state idle;
        transition 'idle-scanning'
            first idle
            accept StartSignal
            then scanning;
        state scanning;
        transition 'scanning-detecting'
            first scanning
            accept ImageCaptured
            then detecting;
        state detecting;
        transition 'detecting-navigating'
            first detecting
            accept WeedDetected
            then navigating;
        state navigating;
        transition 'navigating-weeding'
            first navigating
            accept LocationReached
            then weeding;
        state weeding;
        transition 'weeding-scanning'
            first weeding
            accept WeedRemoved
            then scanning;
        transition 'scanning-returning'
            first scanning
            accept BatteryLow
            then returningToBase;
        transition 'detecting-returning'
            first detecting
            accept BatteryLow
            then returningToBase;
        transition 'navigating-returning'
            first navigating
            accept BatteryLow
            then returningToBase;
        transition 'weeding-returning'
            first weeding
            accept BatteryLow
            then returningToBase;
        state returningToBase;
        transition 'returningToBase-charging'
            first returningToBase
            accept Docked
            then charging;
        state charging;
        transition 'charging-idle'
            first charging
            accept ChargeComplete
            then idle;
    }

    part def BatteryPack {
        attribute capacity : EnergyValue;
        attribute currentCharge : EnergyValue;
        port powerOut {
            out power : ElectricalPower;
        }
        perform action monitorBattery : MonitorBattery;
    }
    part def DriveSystem {
        port powerIn {
            in power : ElectricalPower;
        }
        port cmdIn {
            in command : DriveCommand;
        }
        perform action drive : DriveAction;
    }
    part def CameraSystem {
        port powerIn {
            in power : ElectricalPower;
        }
        port imgOut {
            out image : Image;
        }
        perform action captureImage : CaptureImage;
    }
    part def VisionProcessor {
        port powerIn {
            in power : ElectricalPower;
        }
        port imgIn {
            in image : Image;
        }
        port targetOut {
            out target : WeedTarget;
        }
        perform action processImage : ProcessImage;
    }
    part def GPSNavigationSystem {
        port powerIn {
            in power : ElectricalPower;
        }
        port posOut {
            out position : GPSPosition;
        }
        perform action navigate : Navigate;
    }
    part def MechanicalWeeder {
        port powerIn {
            in power : ElectricalPower;
        }
        port cmdIn {
            in command : WeederCommand;
        }
        perform action deployWeeder : DeployWeeder;
        perform action retractWeeder : RetractWeeder;
    }
    part def ControlComputer {
        port powerIn {
            in power : ElectricalPower;
        }
        port targetIn {
            in target : WeedTarget;
        }
        port posIn {
            in position : GPSPosition;
        }
        port driveCmdOut {
            out command : DriveCommand;
        }
        port weederCmdOut {
            out command : WeederCommand;
        }
        perform action coordinateSystem : CoordinateSystem;
    }
    part def ChargingStation {
        port powerOut {
            out power : ElectricalPower;
        }
    }

    part def FarmWiseWeeder {
        attribute totalMass : MassValue;
        attribute cropSafetyRate : Real;
        attribute powerConsumption : PowerValue;

        part battery : BatteryPack;
        part drive : DriveSystem;
        part camera : CameraSystem;
        part vision : VisionProcessor;
        part gps : GPSNavigationSystem;
        part weeder : MechanicalWeeder;
        part controller : ControlComputer;

        interface batteryToDrive connect battery.powerOut to drive.powerIn {
            flow powerFlow of ElectricalPower from battery.powerOut.power to drive.powerIn.power;
        }
        interface batteryToCamera connect battery.powerOut to camera.powerIn {
            flow powerFlow of ElectricalPower from battery.powerOut.power to camera.powerIn.power;
        }
        interface batteryToVision connect battery.powerOut to vision.powerIn {
            flow powerFlow of ElectricalPower from battery.powerOut.power to vision.powerIn.power;
        }
        interface batteryToGps connect battery.powerOut to gps.powerIn {
            flow powerFlow of ElectricalPower from battery.powerOut.power to gps.powerIn.power;
        }
        interface batteryToWeeder connect battery.powerOut to weeder.powerIn {
            flow powerFlow of ElectricalPower from battery.powerOut.power to weeder.powerIn.power;
        }
        interface batteryToController connect battery.powerOut to controller.powerIn {
            flow powerFlow of ElectricalPower from battery.powerOut.power to controller.powerIn.power;
        }

        interface cameraToVision connect camera.imgOut to vision.imgIn {
            flow imageFlow of Image from camera.imgOut.image to vision.imgIn.image;
        }
        interface visionToController connect vision.targetOut to controller.targetIn {
            flow targetFlow of WeedTarget from vision.targetOut.target to controller.targetIn.target;
        }
        interface gpsToController connect gps.posOut to controller.posIn {
            flow positionFlow of GPSPosition from gps.posOut.position to controller.posIn.position;
        }
        interface controllerToDrive connect controller.driveCmdOut to drive.cmdIn {
            flow driveCmdFlow of DriveCommand from controller.driveCmdOut.command to drive.cmdIn.command;
        }
        interface controllerToWeeder connect controller.weederCmdOut to weeder.cmdIn {
            flow weederCmdFlow of WeederCommand from controller.weederCmdOut.command to weeder.cmdIn.command;
        }

        exhibit state weederStates : WeederStates;
    }

    requirement def OperationalAutonomyRequirement {
        doc /* The weeder must operate for at least 8 hours on a single charge. */
        subject weeder : FarmWiseWeeder;
        attribute minDuration : TimeValue = 8 [h];
        assert constraint { weeder.battery.capacity / weeder.powerConsumption >= minDuration }
    }

    requirement def CropSafetyRequirement {
        doc /* The weeder must achieve a crop safety rate of over 98%. */
        subject weeder : FarmWiseWeeder;
        attribute minSafetyRate : Real = 98;
        assert constraint { weeder.cropSafetyRate > minSafetyRate }
    }

    requirement def ChemicalFreeRequirement {
        doc /* The system shall remove weeds without using chemical herbicides. */
        subject weeder : FarmWiseWeeder;
    }

    part weederSystem : FarmWiseWeeder {
        attribute :>> totalMass = 150 [kg];
        attribute :>> cropSafetyRate = 99;
        attribute :>> powerConsumption = 250 [W];

        part :>> battery {
            attribute :>> capacity = 7200000 [J];
            attribute :>> currentCharge = 7200000 [J];
        }

        exhibit state :>> weederStates;
    }

    part chargingStation : ChargingStation;

    requirement operationalAutonomy : OperationalAutonomyRequirement;
    requirement cropSafety : CropSafetyRequirement;
    requirement chemicalFree : ChemicalFreeRequirement;

    satisfy operationalAutonomy by weederSystem.battery;
    satisfy cropSafety by weederSystem.weeder;
    satisfy chemicalFree by weederSystem;
}
