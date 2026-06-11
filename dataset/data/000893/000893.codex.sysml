package HoneywagonSystemModel {

    import ScalarValues::*;
    import SI::*;

    attribute def Liter;
    attribute def LiterPerMinute;
    attribute def Kilopascal;
    attribute def Kilogram;
    attribute def Percent;
    attribute def Minute;
    attribute def BooleanValue;

    item def Wastewater {
        attribute volume : Liter;
        attribute solidsFraction : Percent;
        attribute odorPotential : Percent;
    }

    item def RinseWater {
        attribute volume : Liter;
        attribute disinfectantConcentration : Percent;
    }

    item def VacuumAir {
        attribute pressure : Kilopascal;
        attribute flowRate : LiterPerMinute;
    }

    item def ServiceStatus {
        attribute tankFillLevel : Percent;
        attribute vacuumAvailable : BooleanValue;
        attribute dischargeReady : BooleanValue;
        attribute sanitationComplete : BooleanValue;
    }

    port def WasteInletPort {
        in item incomingWaste : Wastewater;
        out item inletStatus : ServiceStatus;
    }

    port def WasteOutletPort {
        out item dischargedWaste : Wastewater;
        out item outletStatus : ServiceStatus;
    }

    port def RinsePort {
        out item rinseFlow : RinseWater;
    }

    port def VacuumPort {
        out item vacuumFlow : VacuumAir;
    }

    port def OperatorControlPort {
        in item command : ServiceCommand;
        out item status : ServiceStatus;
    }

    item def ServiceCommand {
        attribute requestCollection : BooleanValue;
        attribute requestDischarge : BooleanValue;
        attribute requestRinse : BooleanValue;
        attribute emergencyStop : BooleanValue;
    }

    part def VacuumPump {
        attribute ratedVacuum : Kilopascal = 70;
        attribute ratedFlow : LiterPerMinute = 1200;
        attribute running : BooleanValue;

        port vacuumOutlet : VacuumPort;

        action def StartPump {
            out item producedVacuum : VacuumAir;
        }

        action def StopPump {
            out item stoppedStatus : ServiceStatus;
        }
    }

    part def WasteHoldingTank {
        attribute capacity : Liter = 3800;
        attribute currentVolume : Liter;
        attribute fillLevel : Percent;
        attribute maximumSafeFillLevel : Percent = 90;

        port inlet : WasteInletPort;
        port outlet : WasteOutletPort;

        action def StoreWaste {
            in item collectedWaste : Wastewater;
            out item tankStatus : ServiceStatus;
        }

        action def EmptyTank {
            out item removedWaste : Wastewater;
            out item tankStatus : ServiceStatus;
        }
    }

    part def HoseAssembly {
        attribute length : Meter = 9;
        attribute nominalDiameter : Millimeter = 76;
        attribute connected : BooleanValue;

        port sourceEnd : WasteInletPort;
        port tankEnd : WasteInletPort;

        action def ConnectToWasteSource {
            out item connectionStatus : ServiceStatus;
        }

        action def DisconnectFromWasteSource {
            out item connectionStatus : ServiceStatus;
        }
    }

    attribute def Meter;
    attribute def Millimeter;

    part def RinseSystem {
        attribute rinseTankCapacity : Liter = 250;
        attribute availableRinseWater : Liter;
        attribute rinseFlowRate : LiterPerMinute = 35;

        port rinseOutlet : RinsePort;

        action def RinseHoseAndFittings {
            out item rinseWaterUsed : RinseWater;
            out item sanitationStatus : ServiceStatus;
        }
    }

    part def DischargeValve {
        attribute open : BooleanValue;
        attribute lockedClosed : BooleanValue;

        port tankSide : WasteOutletPort;
        port disposalSide : WasteOutletPort;

        action def OpenForDischarge {
            out item valveStatus : ServiceStatus;
        }

        action def CloseAfterDischarge {
            out item valveStatus : ServiceStatus;
        }
    }

    part def OperatorPanel {
        port controls : OperatorControlPort;

        action def IssueCollectionCommand {
            out item command : ServiceCommand;
        }

        action def IssueDischargeCommand {
            out item command : ServiceCommand;
        }

        action def IssueEmergencyStop {
            out item command : ServiceCommand;
        }
    }

    part def Honeywagon {
        doc /* A honeywagon is a mobile sanitary service system whose primary high-level function is to collect, contain, transport, and discharge wastewater from temporary or remote sanitation sources. */

        attribute grossVehicleMass : Kilogram = 7200;
        attribute nominalWasteCapacity : Liter = 3800;
        attribute collectionRate : LiterPerMinute = 450;
        attribute maximumServiceTime : Minute = 25;

        port serviceInlet : WasteInletPort;
        port disposalOutlet : WasteOutletPort;
        port operatorInterface : OperatorControlPort;

        part pump : VacuumPump;
        part tank : WasteHoldingTank;
        part hose : HoseAssembly;
        part rinseSystem : RinseSystem;
        part dischargeValve : DischargeValve;
        part operatorPanel : OperatorPanel;

        connect serviceInlet to hose.sourceEnd;
        connect hose.tankEnd to tank.inlet;
        connect pump.vacuumOutlet to tank.inlet;
        connect tank.outlet to dischargeValve.tankSide;
        connect dischargeValve.disposalSide to disposalOutlet;
        connect operatorPanel.controls to operatorInterface;

        action def PerformWasteCollection {
            in item wasteAtSource : Wastewater;
            out item containedWaste : Wastewater;
            out item serviceStatus : ServiceStatus;

            action connectHose : HoseAssembly::ConnectToWasteSource;
            action startVacuum : VacuumPump::StartPump;
            action storeWaste : WasteHoldingTank::StoreWaste;
            action rinseFittings : RinseSystem::RinseHoseAndFittings;
            action stopVacuum : VacuumPump::StopPump;
            action disconnectHose : HoseAssembly::DisconnectFromWasteSource;

            flow wasteAtSource to storeWaste.collectedWaste;
            flow storeWaste.tankStatus to serviceStatus;
            flow storeWaste.collectedWaste to containedWaste;
        }

        action def PerformControlledDischarge {
            out item dischargedWaste : Wastewater;
            out item serviceStatus : ServiceStatus;

            action openValve : DischargeValve::OpenForDischarge;
            action emptyTank : WasteHoldingTank::EmptyTank;
            action closeValve : DischargeValve::CloseAfterDischarge;

            flow emptyTank.removedWaste to dischargedWaste;
            flow closeValve.valveStatus to serviceStatus;
        }

        state def OperatingStateMachine {
            state Idle;
            state Connecting;
            state Collecting;
            state Containing;
            state Transporting;
            state Discharging;
            state Rinsing;
            state EmergencyStopped;

            transition initial then Idle;

            transition Idle_to_Connecting
                first Idle
                accept ServiceCommand
                if command.requestCollection
                then Connecting;

            transition Connecting_to_Collecting
                first Connecting
                then Collecting;

            transition Collecting_to_Containing
                first Collecting
                if tank.fillLevel < tank.maximumSafeFillLevel
                then Containing;

            transition Collecting_to_EmergencyStopped
                first Collecting
                accept ServiceCommand
                if command.emergencyStop
                then EmergencyStopped;

            transition Containing_to_Transporting
                first Containing
                then Transporting;

            transition Transporting_to_Discharging
                first Transporting
                accept ServiceCommand
                if command.requestDischarge
                then Discharging;

            transition Discharging_to_Rinsing
                first Discharging
                then Rinsing;

            transition Rinsing_to_Idle
                first Rinsing
                then Idle;

            transition Any_to_EmergencyStopped
                accept ServiceCommand
                if command.emergencyStop
                then EmergencyStopped;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject honeywagon : Honeywagon;

        doc /* The honeywagon shall provide mobile collection, sealed containment, transport, and controlled discharge of wastewater from field sanitation assets. */

        require constraint {
            honeywagon.nominalWasteCapacity >= 3000
        }
    }

    requirement def VacuumCollectionRequirement {
        subject honeywagon : Honeywagon;

        require constraint {
            honeywagon.pump.ratedVacuum >= 60 and
            honeywagon.collectionRate >= 300
        }
    }

    requirement def ContainmentRequirement {
        subject honeywagon : Honeywagon;

        require constraint {
            honeywagon.tank.fillLevel <= honeywagon.tank.maximumSafeFillLevel
        }
    }

    requirement def SanitationRequirement {
        subject honeywagon : Honeywagon;

        require constraint {
            honeywagon.rinseSystem.availableRinseWater >= 20
        }
    }

    requirement def ControlledDischargeRequirement {
        subject honeywagon : Honeywagon;

        require constraint {
            honeywagon.dischargeValve.lockedClosed == true or
            honeywagon.dischargeValve.open == true
        }
    }

    part honeywagonSystem : Honeywagon;
}