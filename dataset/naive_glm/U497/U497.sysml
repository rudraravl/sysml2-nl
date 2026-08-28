package FirePumpingSubsystem {
    import SI::*;

    // ---- Value Types ----
    value type PressureValue :> Real { unit 'Pa'; }
    value type FlowRateValue :> Real { unit 'm3/s'; }
    value type RotationalSpeed :> Real { unit 'rad/s'; }
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Torque :> Real { unit 'N*m'; }
    value type Power :> Real { unit 'W'; }
    value type Duration :> Real { unit 's'; }

    // ---- Item Types ----
    item def Water;
    item def PressurizedWater :> Water;

    // ---- Port Definitions ----
    port def WaterFlowPort {
        in item water : Water;
        out pressure : PressureValue;
        out flowRate : FlowRateValue;
    }

    port def SuctionFlowPort :> WaterFlowPort;
    port def DischargeFlowPort :> WaterFlowPort;

    port def CommandPort {
        in startCommand : Boolean;
        in stopCommand : Boolean;
        in targetPressure : PressureValue;
        in targetFlowRate : FlowRateValue;
    }

    port def SensorDataPort {
        out pressure : PressureValue;
        out flowRate : FlowRateValue;
        out status : String;
    }

    port def ControlPort {
        out runCommand : Boolean;
        out speedCommand : RotationalSpeed;
        out alarmSignal : Boolean;
    }

    port def AlarmPort {
        out alarmSignal : Boolean;
        out faultCode : String;
    }

    // ---- Pump Sub-Components ----
    part def Motor {
        port electricIn {
            in voltage : Voltage;
            in current : Current;
        }
        port mechanicalOut {
            out torque : Torque;
            out speed : RotationalSpeed;
        }
        attribute ratedPower : Power = 75000 [W];
        attribute ratedVoltage : Voltage = 480 [V];
    }

    part def Shaft {
        port driveIn {
            in torque : Torque;
            in speed : RotationalSpeed;
        }
        port driveOut {
            out torque : Torque;
            out speed : RotationalSpeed;
        }
        attribute length : Real = 0.5 [m];
    }

    part def Impeller {
        port driveIn {
            in torque : Torque;
            in speed : RotationalSpeed;
        }
        port fluidIn : SuctionFlowPort;
        port fluidOut : DischargeFlowPort;
        attribute diameter : Real = 0.3 [m];
        attribute bladeCount : Integer = 7;
    }

    part def Casing {
        port suction : SuctionFlowPort;
        port discharge : DischargeFlowPort;
        attribute material : String = "DuctileIron";
        attribute maxPressure : PressureValue = 2000000 [Pa];
    }

    part def FirePump {
        part motor : Motor;
        part shaft : Shaft;
        part impeller : Impeller;
        part casing : Casing;

        port suctionPort : SuctionFlowPort;
        port dischargePort : DischargeFlowPort;
        port controlPort : ControlPort;

        connection motorToShaft connect motor.mechanicalOut to shaft.driveIn;
        connection shaftToImpeller connect shaft.driveOut to impeller.driveIn;
        connection suctionToCasing connect suctionPort to casing.suction;
        connection casingToImpeller connect casing.suction to impeller.fluidIn;
        connection impellerToCasing connect impeller.fluidOut to casing.discharge;
        connection casingToDischarge connect casing.discharge to dischargePort;

        attribute ratedFlow : FlowRateValue = 0.05 [m3/s];
        attribute ratedHead : PressureValue = 1000000 [Pa];
    }

    // ---- External Components ----
    part def WaterSupplySource {
        port outlet : SuctionFlowPort;
        attribute capacity : Real = 10000 [m3];
        attribute staticPressure : PressureValue = 101325 [Pa];
        attribute minLevel : Real = 0.5 [m];
    }

    part def DischargeManifold {
        port inlet : DischargeFlowPort;
        port outlet1 : DischargeFlowPort;
        port outlet2 : DischargeFlowPort;
        port outlet3 : DischargeFlowPort;
        attribute maxOutlets : Integer = 3;
        attribute ratedPressure : PressureValue = 1500000 [Pa];
    }

    part def BuildingFireNetwork {
        port inlet1 : DischargeFlowPort;
        port inlet2 : DischargeFlowPort;
        port inlet3 : DischargeFlowPort;
        attribute sprinklerCount : Integer = 250;
    }

    // ---- Sensors ----
    part def SuctionPressureSensor {
        port measurePort : SuctionFlowPort;
        port dataOut : SensorDataPort;
        attribute minThreshold : PressureValue = 50000 [Pa];
        attribute accuracy : Real = 0.01;
    }

    part def DischargePressureSensor {
        port measurePort : DischargeFlowPort;
        port dataOut : SensorDataPort;
        attribute maxThreshold : PressureValue = 1500000 [Pa];
        attribute accuracy : Real = 0.01;
    }

    part def FlowMeter {
        port measurePort : DischargeFlowPort;
        port dataOut : SensorDataPort;
        attribute minFlowRate : FlowRateValue = 0.001 [m3/s];
        attribute accuracy : Real = 0.02;
    }

    // ---- Controller ----
    part def PumpController {
        port commandIn : CommandPort;
        port suctionDataIn : SensorDataPort;
        port dischargeDataIn : SensorDataPort;
        port flowDataIn : SensorDataPort;
        port controlOut : ControlPort;
        port alarmOut : AlarmPort;

        attribute targetPressure : PressureValue = 1000000 [Pa];
        attribute targetFlowRate : FlowRateValue = 0.05 [m3/s];
        attribute primingTimeout : Duration = 30 [s];
        attribute lowSuctionThreshold : PressureValue = 50000 [Pa];
        attribute highDischargeThreshold : PressureValue = 1500000 [Pa];

        state def ControllerStates {
            entry; then Off;

            state Off {
                entry action { controlOut.runCommand = false; }
            }

            transition from Off to Priming
                when commandIn.startCommand == true;

            state Priming {
                entry action { controlOut.runCommand = true; controlOut.speedCommand = 50 [rad/s]; }
            }

            transition from Priming to Running
                when suctionDataIn.pressure >= lowSuctionThreshold;

            transition from Priming to Alarm
                when primingTimeout exceeded;

            state Running {
                entry action { controlOut.runCommand = true; controlOut.speedCommand = 314 [rad/s]; }
            }

            transition from Running to ControlledShutdown
                when commandIn.stopCommand == true;

            transition from Running to Alarm
                when suctionDataIn.pressure < lowSuctionThreshold;

            transition from Running to Alarm
                when dischargeDataIn.pressure > highDischargeThreshold;

            state ControlledShutdown {
                entry action { controlOut.speedCommand = 0 [rad/s]; }
                do action { controlOut.runCommand = false; }
            }

            transition from ControlledShutdown to Off
                when controlOut.runCommand == false;

            state Alarm {
                entry action { alarmOut.alarmSignal = true; controlOut.runCommand = false; }
            }

            transition from Alarm to Off
                when commandIn.stopCommand == true;
        }

        part behavior : ControllerStates;
    }

    // ---- Top-Level System ----
    part def FirePumpingSystem {
        port commandPort : CommandPort;
        port alarmPort : AlarmPort;
        port networkPort1 : DischargeFlowPort;
        port networkPort2 : DischargeFlowPort;
        port networkPort3 : DischargeFlowPort;

        part waterSupply : WaterSupplySource;
        part firePump : FirePump;
        part manifold : DischargeManifold;
        part controller : PumpController;
        part suctionSensor : SuctionPressureSensor;
        part dischargeSensor : DischargePressureSensor;
        part flowMeter : FlowMeter;
        part buildingNetwork : BuildingFireNetwork;

        connection supplyToPump connect waterSupply.outlet to firePump.suctionPort;
        connection pumpToManifold connect firePump.dischargePort to manifold.inlet;
        connection manifoldToNetwork1 connect manifold.outlet1 to buildingNetwork.inlet1;
        connection manifoldToNetwork2 connect manifold.outlet2 to buildingNetwork.inlet2;
        connection manifoldToNetwork3 connect manifold.outlet3 to buildingNetwork.inlet3;
        connection network1ToPort connect buildingNetwork.inlet1 to networkPort1;
        connection network2ToPort connect buildingNetwork.inlet2 to networkPort2;
        connection network3ToPort connect buildingNetwork.inlet3 to networkPort3;

        connection suctionSensorTap connect firePump.suctionPort to suctionSensor.measurePort;
        connection dischargeSensorTap connect firePump.dischargePort to dischargeSensor.measurePort;
        connection flowMeterTap connect firePump.dischargePort to flowMeter.measurePort;

        connection suctionDataToController connect suctionSensor.dataOut to controller.suctionDataIn;
        connection dischargeDataToController connect dischargeSensor.dataOut to controller.dischargeDataIn;
        connection flowDataToController connect flowMeter.dataOut to controller.flowDataIn;

        connection controllerToPump connect controller.controlOut to firePump.controlPort;
        connection commandToController connect commandPort to controller.commandIn;
        connection alarmFromController connect controller.alarmOut to alarmPort;
    }

    // ---- Requirements ----
    requirement def PerformanceRequirement {
        attribute minFlowRate : FlowRateValue = 0.05 [m3/s];
        attribute minDischargePressure : PressureValue = 1000000 [Pa];
        attribute maxStartupTime : Duration = 30 [s];
        subject pumpSystem : FirePumpingSystem;
        require { pumpSystem.firePump.ratedFlow >= minFlowRate; }
        require { pumpSystem.firePump.ratedHead >= minDischargePressure; }
    }

    requirement def ReliabilityRequirement {
        attribute minContinuousRunTime : Duration = 3600 [s];
        subject pumpSystem : FirePumpingSystem;
        require { pumpSystem.controller.primingTimeout <= 30 [s]; }
    }

    requirement def SafetyRequirement {
        attribute lowSuctionLimit : PressureValue = 50000 [Pa];
        attribute highDischargeLimit : PressureValue = 1500000 [Pa];
        subject pumpSystem : FirePumpingSystem;
        require { pumpSystem.suctionSensor.minThreshold <= lowSuctionLimit; }
        require { pumpSystem.dischargeSensor.maxThreshold >= highDischargeLimit; }
    }

    requirement def StartupRequirement {
        attribute maxStartupDuration : Duration = 30 [s];
        subject pumpSystem : FirePumpingSystem;
        require { pumpSystem.controller.primingTimeout <= maxStartupDuration; }
    }

    requirement FirePumpPerformance : PerformanceRequirement {
        doc /* The fire pump shall deliver at least 0.05 m3/s at 1 MPa discharge pressure. */
    }

    requirement FirePumpReliability : ReliabilityRequirement {
        doc /* The system shall start within 30 seconds and operate continuously for at least 1 hour. */
    }

    requirement FirePumpSafety : SafetyRequirement {
        doc /* The controller shall trigger alarm and shutdown on unsafe suction or discharge pressures. */
    }

    requirement FirePumpStartup : StartupRequirement {
        doc /* The system shall complete priming and reach running state within 30 seconds of a start command. */
    }
}
