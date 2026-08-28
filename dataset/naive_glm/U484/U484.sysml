package CondensatePumpingSubsystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type PressureValue :> Real { unit 'Pa'; }
    value type FlowRateValue :> Real { unit 'm3/s'; }
    value type LevelValue :> Real { unit 'm'; }
    value type VolumeValue :> Real { unit 'm3'; }
    value type PowerValue :> Real { unit 'W'; }
    value type TemperatureValue :> Real { unit 'K'; }
    value type LengthValue :> Real { unit 'm'; }
    value type AreaValue :> Real { unit 'm2'; }
    value type DensityValue :> Real { unit 'kg/m3'; }
    value type SpeedValue :> Real { unit 'rad/s'; }
    value type VoltageValue :> Real { unit 'V'; }
    value type CurrentValue :> Real { unit 'A'; }
    value type TimeValue :> Real { unit 's'; }

    // ===== Item Definitions =====
    item def Condensate {
        attribute temperature : TemperatureValue = 350;
        attribute density : DensityValue = 965;
    }

    // ===== Port Definitions =====
    port def FluidPort {
        in out item condensate : Condensate;
    }

    port def PressureSignalPort {
        in out attribute pressure : PressureValue;
    }

    port def FlowSignalPort {
        in out attribute flowRate : FlowRateValue;
    }

    port def LevelSignalPort {
        in out attribute level : LevelValue;
    }

    port def ControlSignalPort {
        in out attribute startCommand : Boolean;
        in out attribute stopCommand : Boolean;
    }

    port def PumpStatusPort {
        in out attribute running : Boolean;
        in out attribute faulted : Boolean;
    }

    port def ElectricPowerPort {
        in out attribute voltage : VoltageValue;
        in out attribute current : CurrentValue;
    }

    // ===== Requirement Definitions =====
    requirement def CollectCondensateRequirement {
        doc /* The system shall collect incoming condensate in a receiver tank acting as a temporary collection point. */
        attribute minCapacity : VolumeValue = 1.0;
        attribute maxCapacity : VolumeValue = 2.0;
        constraint { minCapacity > 0 and maxCapacity >= minCapacity }
    }

    requirement def AutoStartPumpRequirement {
        doc /* The pump shall start automatically when the receiver level reaches a pre-set high point. */
        attribute highSetpoint : LevelValue = 1.5;
        attribute maxResponseTime : TimeValue = 5.0;
        constraint { highSetpoint >= 1.0 and maxResponseTime <= 10.0 }
    }

    requirement def AutoStopPumpRequirement {
        doc /* The pump shall stop automatically when the receiver level falls below a pre-set low point. */
        attribute lowSetpoint : LevelValue = 0.3;
        constraint { lowSetpoint > 0 and lowSetpoint <= 0.5 }
    }

    requirement def TransferCondensateRequirement {
        doc /* The system shall transfer pressurized condensate through discharge piping to a storage tank for reuse. */
        attribute minFlowRate : FlowRateValue = 0.01;
        attribute maxFlowRate : FlowRateValue = 0.05;
        constraint { minFlowRate > 0 and maxFlowRate > minFlowRate }
    }

    requirement def MonitorPressureRequirement {
        doc /* Pressure transmitters shall monitor suction and discharge pressures at the pump inlet and outlet to verify pump performance. */
        attribute suctionRangeMax : PressureValue = 100000;
        attribute dischargeRangeMax : PressureValue = 500000;
        constraint { suctionRangeMax > 0 and dischargeRangeMax > suctionRangeMax }
    }

    requirement def MonitorFlowRequirement {
        doc /* A flow transmitter shall measure the condensate transfer rate in the discharge piping. */
        attribute flowRangeMax : FlowRateValue = 0.1;
        attribute accuracy : FlowRateValue = 0.001;
        constraint { flowRangeMax > 0 and accuracy > 0 }
    }

    requirement def SafeOperationRequirement {
        doc /* The pump shall enter a faulted state when abnormal suction or discharge pressures are detected. */
        attribute minSuctionPressure : PressureValue = 10000;
        attribute minDischargePressure : PressureValue = 100000;
        constraint { minSuctionPressure > 0 and minDischargePressure > 0 }
    }

    // ===== Part Definitions =====

    part def LevelSensor {
        port levelOut : LevelSignalPort;

        attribute measuredLevel : LevelValue;
        attribute lowSetpoint : LevelValue = 0.3;
        attribute highSetpoint : LevelValue = 1.5;
        attribute accuracy : LevelValue = 0.01;
        attribute fault : Boolean = false;

        action measureLevel(in actualLevel : LevelValue) {
            // Update measured level from actual tank level
        }

        action detectFault {
            // Detect sensor out-of-range or signal loss
        }
    }

    part def PressureTransmitter {
        port pressureOut : PressureSignalPort;

        attribute measuredPressure : PressureValue;
        attribute rangeMin : PressureValue = 0;
        attribute rangeMax : PressureValue = 600000;
        attribute accuracy : PressureValue = 500;
        attribute fault : Boolean = false;

        action measurePressure(in actualPressure : PressureValue) {
            // Update measured pressure from actual line pressure
        }

        action detectFault {
            // Detect transmitter out-of-range or signal loss
        }
    }

    part def FlowTransmitter {
        port flowOut : FlowSignalPort;

        attribute measuredFlow : FlowRateValue;
        attribute rangeMin : FlowRateValue = 0;
        attribute rangeMax : FlowRateValue = 0.1;
        attribute accuracy : FlowRateValue = 0.001;
        attribute fault : Boolean = false;

        action measureFlow(in actualFlow : FlowRateValue) {
            // Update measured flow from actual discharge flow
        }

        action detectFault {
            // Detect transmitter out-of-range or signal loss
        }
    }

    part def ElectricMotor {
        port powerIn : ElectricPowerPort;

        attribute ratedPower : PowerValue = 7500;
        attribute ratedSpeed : SpeedValue = 157;
        attribute currentSpeed : SpeedValue = 0;
        attribute running : Boolean = false;
        attribute faulted : Boolean = false;

        action startMotor {
            // Ramp motor speed up toward rated speed
        }

        action stopMotor {
            // Ramp motor speed down to zero
        }

        state def MotorStates {
            initial state Off {
                entry { running = false; currentSpeed = 0; }
            }
            state Starting {
                entry { running = false; }
                do { startMotor; }
            }
            state Running {
                entry { running = true; currentSpeed = ratedSpeed; }
            }
            state Stopping {
                entry { running = false; }
                do { stopMotor; }
            }
            state Faulted {
                entry { faulted = true; running = false; currentSpeed = 0; }
            }

            transition m1 first Off if true then Starting;
            transition m2 first Starting if currentSpeed >= ratedSpeed * 0.95 then Running;
            transition m3 first Starting if faulted == true then Faulted;
            transition m4 first Running if true then Stopping;
            transition m5 first Stopping if currentSpeed <= 0 then Off;
            transition m6 first Running if faulted == true then Faulted;
        }

        state machine motorState : MotorStates;
    }

    part def CondensateReceiver {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port levelPort1 : LevelSignalPort;
        port levelPort2 : LevelSignalPort;

        attribute volume : VolumeValue = 0;
        attribute maxVolume : VolumeValue = 2.0;
        attribute currentLevel : LevelValue = 0;
        attribute crossSectionArea : AreaValue = 1.0;
        attribute inletTemperature : TemperatureValue = 350;

        part levelSensor1 : LevelSensor;
        part levelSensor2 : LevelSensor;

        connect levelPort1 to levelSensor1.levelOut;
        connect levelPort2 to levelSensor2.levelOut;

        action receiveCondensate(in incoming : Condensate) {
            // Accumulate incoming condensate, update volume and level
        }

        action dischargeCondensate(out outgoing : Condensate) {
            // Release condensate to pump suction line
        }

        action updateLevel {
            // Calculate currentLevel = volume / crossSectionArea
        }
    }

    part def CondensatePump {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port inletPressurePort : PressureSignalPort;
        port outletPressurePort : PressureSignalPort;
        port controlPort : ControlSignalPort;
        port statusPort : PumpStatusPort;
        port powerPort : ElectricPowerPort;

        attribute ratedPower : PowerValue = 7500;
        attribute ratedFlow : FlowRateValue = 0.05;
        attribute suctionPressure : PressureValue = 0;
        attribute dischargePressure : PressureValue = 0;
        attribute running : Boolean = false;
        attribute faulted : Boolean = false;
        attribute startCommand : Boolean = false;
        attribute stopCommand : Boolean = false;
        attribute totalRunTime : TimeValue = 0;

        part motor : ElectricMotor;

        connect motor.powerIn to powerPort;

        action pumpCondensate {
            // Draw condensate from inlet, pressurize, and discharge through outlet
        }

        action checkFaults {
            // Evaluate suction and discharge pressures for fault conditions
        }

        state def PumpStates {
            initial state Off {
                entry { running = false; }
                exit { faulted = false; }
            }

            state Starting {
                entry { running = false; }
                do { motor.startMotor; }
            }

            state Running {
                entry { running = true; }
                do { pumpCondensate; }
            }

            state Stopping {
                entry { running = false; }
                do { motor.stopMotor; }
            }

            state Faulted {
                entry { faulted = true; running = false; }
            }

            transition p1 first Off if startCommand == true then Starting;
            transition p2 first Starting if suctionPressure > 50000 and dischargePressure > 200000 then Running;
            transition p3 first Starting if suctionPressure < 20000 then Faulted;
            transition p4 first Running if stopCommand == true then Stopping;
            transition p5 first Running if dischargePressure < 100000 then Faulted;
            transition p6 first Running if suctionPressure < 10000 then Faulted;
            transition p7 first Stopping if true then Off;
            transition p8 first Faulted if stopCommand == true and startCommand == false then Off;
        }

        state machine pumpState : PumpStates;
    }

    part def DischargePiping {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port flowPort : FlowSignalPort;

        attribute length : LengthValue = 50.0;
        attribute diameter : LengthValue = 0.05;
        attribute flowRate : FlowRateValue = 0;
        attribute pressureDrop : PressureValue = 0;

        part flowTransmitter : FlowTransmitter;

        connect flowPort to flowTransmitter.flowOut;

        action transferCondensate {
            // Transfer condensate from inlet to outlet with pressure drop
        }
    }

    part def StorageTank {
        port inlet : FluidPort;

        attribute volume : VolumeValue = 0;
        attribute maxVolume : VolumeValue = 50.0;
        attribute currentLevel : LevelValue = 0;
        attribute crossSectionArea : AreaValue = 5.0;
        attribute temperature : TemperatureValue = 340;

        action storeCondensate(in incoming : Condensate) {
            // Accumulate condensate in storage tank for reuse
        }

        action updateLevel {
            // Calculate currentLevel = volume / crossSectionArea
        }
    }

    part def PumpController {
        port levelIn1 : LevelSignalPort;
        port levelIn2 : LevelSignalPort;
        port controlOut : ControlSignalPort;
        port statusIn : PumpStatusPort;

        attribute highSetpoint : LevelValue = 1.5;
        attribute lowSetpoint : LevelValue = 0.3;
        attribute startCommand : Boolean = false;
        attribute stopCommand : Boolean = false;
        attribute pumpRunning : Boolean = false;
        attribute pumpFaulted : Boolean = false;
        attribute autoMode : Boolean = true;

        action evaluateLevels(in level1 : LevelValue, in level2 : LevelValue) {
            // Average the two sensor readings and compare against setpoints
        }

        action issueStartCommand {
            // Set startCommand true, stopCommand false
        }

        action issueStopCommand {
            // Set stopCommand true, startCommand false
        }

        state def ControllerStates {
            initial state Idle {
                entry { startCommand = false; stopCommand = false; }
            }

            state StartCommanded {
                entry { startCommand = true; stopCommand = false; }
                do { issueStartCommand; }
            }

            state Monitoring {
                entry { startCommand = false; stopCommand = false; }
            }

            state StopCommanded {
                entry { stopCommand = true; startCommand = false; }
                do { issueStopCommand; }
            }

            state FaultDetected {
                entry { stopCommand = true; startCommand = false; }
            }

            transition c1 first Idle if levelIn1.level >= highSetpoint then StartCommanded;
            transition c2 first StartCommanded if statusIn.running == true then Monitoring;
            transition c3 first Monitoring if levelIn1.level <= lowSetpoint then StopCommanded;
            transition c4 first Monitoring if statusIn.faulted == true then FaultDetected;
            transition c5 first StopCommanded if statusIn.running == false then Idle;
            transition c6 first FaultDetected if autoMode == false and startCommand == false then Idle;
        }

        state machine controllerState : ControllerStates;
    }

    // ===== System Definition =====
    part def CondensatePumpingSystem {
        requirement r1 : CollectCondensateRequirement;
        requirement r2 : AutoStartPumpRequirement;
        requirement r3 : AutoStopPumpRequirement;
        requirement r4 : TransferCondensateRequirement;
        requirement r5 : MonitorPressureRequirement;
        requirement r6 : MonitorFlowRequirement;
        requirement r7 : SafeOperationRequirement;

        port systemInlet : FluidPort;
        port systemOutlet : FluidPort;

        part receiver : CondensateReceiver;
        part inletPressureTransmitter : PressureTransmitter;
        part outletPressureTransmitter : PressureTransmitter;
        part pump : CondensatePump;
        part piping : DischargePiping;
        part storageTank : StorageTank;
        part controller : PumpController;

        // External port delegation
        connect systemInlet to receiver.inlet;
        connect storageTank.inlet to systemOutlet;

        // Fluid connections
        connection receiverToPump connect receiver.outlet to pump.inlet;
        connection pumpToPiping connect pump.outlet to piping.inlet;
        connection pipingToStorage connect piping.outlet to storageTank.inlet;

        // Pressure transmitter connections
        connection inletPTToPump connect inletPressureTransmitter.pressureOut to pump.inletPressurePort;
        connection outletPTToPump connect outletPressureTransmitter.pressureOut to pump.outletPressurePort;

        // Level sensor connections to controller
        connection levelSensor1ToController connect receiver.levelPort1 to controller.levelIn1;
        connection levelSensor2ToController connect receiver.levelPort2 to controller.levelIn2;

        // Control and status connections
        connection controllerToPump connect controller.controlOut to pump.controlPort;
        connection pumpStatusToController connect pump.statusPort to controller.statusIn;

        // Requirement satisfaction
        satisfy r1 by receiver;
        satisfy r2 by controller;
        satisfy r3 by controller;
        satisfy r4 by pump;
        satisfy r4 by piping;
        satisfy r5 by inletPressureTransmitter;
        satisfy r5 by outletPressureTransmitter;
        satisfy r6 by piping;
        satisfy r7 by pump;
    }
}
