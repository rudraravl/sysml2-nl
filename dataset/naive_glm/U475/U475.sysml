package IrrigationPumpingSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----
    value type Pressure {
        :>> unit = SI::Pa;
    }
    value type FlowRate {
        :>> unit = SI::m^3/SI::s;
    }
    value type Voltage {
        :>> unit = SI::V;
    }
    value type ElectricPower {
        :>> unit = SI::W;
    }
    value type RotationalSpeed {
        :>> unit = SI::rad/SI::s;
    }
    value type Length {
        :>> unit = SI::m;
    }
    value type Diameter {
        :>> unit = SI::m;
    }
    value type Mass {
        :>> unit = SI::kg;
    }
    value type Temperature {
        :>> unit = SI::K;
    }

    // ---- Item Types ----
    item def Water;
    item def Debris;
    item def ElectricalEnergy;
    item def ControlSignal;
    item def Grease;

    // ---- Port Definitions ----
    port def FluidPort {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        out item water : Water;
        in item waterIn : Water;
    }
    port def SuctionFluidPort :> FluidPort;
    port def DischargeFluidPort :> FluidPort;
    port def ElectricalPort {
        attribute voltage : Voltage;
        in item energy : ElectricalEnergy;
    }
    port def MechanicalDrivePort {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
    }
    port def ControlPort {
        in item command : ControlSignal;
        out item status : ControlSignal;
    }
    port def PressureSensingPort {
        attribute measuredPressure : Pressure;
        out item pressureReading : ControlSignal;
    }

    // ---- Requirements ----
    requirement def IrrigationRequirement {
        doc "The system shall deliver water from the source to the rice field to meet crop water requirements."
        attribute requiredFlowRate : FlowRate = 0.05 [m^3/s];
        attribute requiredPressure : Pressure = 300000 [Pa];
        subject pumpingSystem : IrrigationPumpingSystem;
        require { pumpingSystem.deliveredFlowRate >= requiredFlowRate }
        require { pumpingSystem.deliveredPressure >= requiredPressure }
    }

    requirement def PumpReliabilityRequirement {
        doc "The pump shall maintain reliable operation throughout the irrigation season using grease-lubricated ball bearings and a silicon carbide mechanical seal."
        attribute minOperatingHours : Real = 2000;
        subject pump : CentrifugalPump;
        require { pump.seal.material == "SiliconCarbide" }
        require { pump.bearings.lubrication == "Grease" }
    }

    requirement def MotorPowerRequirement {
        doc "The motor shall provide 7.5 kW at 480 V to drive the pump at 1750 RPM."
        attribute ratedPower : ElectricPower = 7500 [W];
        attribute ratedVoltage : Voltage = 480 [V];
        attribute nominalSpeed : RotationalSpeed = 183.26 [rad/s];
        subject motor : ElectricMotor;
        require { motor.ratedPower == ratedPower }
        require { motor.ratedVoltage == ratedVoltage }
    }

    requirement def AutomationRequirement {
        doc "The control panel shall automatically start the motor when pressure drops below the lower set point and stop it when pressure reaches the upper limit."
        attribute lowerSetPoint : Pressure = 200000 [Pa];
        attribute upperSetPoint : Pressure = 350000 [Pa];
        subject controlPanel : ControlPanel;
        require { controlPanel.pressureSwitch.lowerSetPoint == lowerSetPoint }
        require { controlPanel.pressureSwitch.upperSetPoint == upperSetPoint }
    }

    // ---- Part Definitions ----

    part def CentrifugalPump {
        attribute manufacturer : String = "A.M. Bohnert";
        attribute material : String = "CastIron";
        attribute impellerVanes : Integer = 6;
        attribute nominalSpeed : RotationalSpeed = 183.26 [rad/s];

        port suctionPort : SuctionFluidPort;
        port dischargePort : DischargeFluidPort;
        port drivePort : MechanicalDrivePort;

        part impeller {
            attribute vanes : Integer = 6;
            attribute material : String = "CastIron";
        }
        part shaft {
            attribute material : String = "StainlessSteel";
            attribute length : Length = 0.5 [m];
        }
        part bearings {
            attribute type : String = "BallBearing";
            attribute lubrication : String = "Grease";
            in item greaseSupply : Grease;
        }
        part seal {
            attribute type : String = "MechanicalSeal";
            attribute material : String = "SiliconCarbide";
        }
        part casing {
            attribute material : String = "CastIron";
        }

        attribute deliveredFlowRate : FlowRate;
        attribute deliveredPressure : Pressure;

        state def PumpLifecycle {
            entry; then off;
            state off;
            state starting;
            state running;
            state stopping;
            transition off_to_starting
                first off
                accept ControlSignal
                then starting;
            transition starting_to_running
                first starting
                accept ControlSignal
                then running;
            transition running_to_stopping
                first running
                accept ControlSignal
                then stopping;
            transition stopping_to_off
                first stopping
                accept ControlSignal
                then off;
        }
        exhibit PumpLifecycle;
    }

    part def ElectricMotor {
        attribute ratedPower : ElectricPower = 7500 [W];
        attribute ratedVoltage : Voltage = 480 [V];
        attribute nominalSpeed : RotationalSpeed = 183.26 [rad/s];

        port powerPort : ElectricalPort;
        port drivePort : MechanicalDrivePort;
        port controlPort : ControlPort;

        attribute currentSpeed : RotationalSpeed;
        attribute running : Boolean = false;

        action def StartMotor {
            in voltage : Voltage = 480 [V];
            then SetSpeed;
            action SetSpeed {
                out speed : RotationalSpeed = 183.26 [rad/s];
            }
        }
        action def StopMotor {
            then SetSpeedZero;
            action SetSpeedZero {
                out speed : RotationalSpeed = 0 [rad/s];
            }
        }
    }

    part def SuctionPipe {
        attribute material : String = "PVC";
        attribute length : Length = 10.0 [m];
        attribute diameter : Diameter = 0.15 [m];

        port inletPort : SuctionFluidPort;
        port outletPort : SuctionFluidPort;
    }

    part def Strainer {
        attribute meshSize : Diameter = 0.003 [m];
        port inletPort : SuctionFluidPort;
        port outletPort : SuctionFluidPort;
        in item debris : Debris;
    }

    part def FootValve {
        attribute type : String = "CheckValve";
        port inletPort : SuctionFluidPort;
        port outletPort : SuctionFluidPort;
        attribute primed : Boolean = true;
    }

    part def DischargePipe {
        attribute material : String = "PVC";
        attribute length : Length = 500.0 [m];
        attribute diameter : Diameter = 0.15 [m];

        port inletPort : DischargeFluidPort;
        port outletPort : DischargeFluidPort;
    }

    part def CheckValve {
        attribute type : String = "SwingCheckValve";
        port inletPort : DischargeFluidPort;
        port outletPort : DischargeFluidPort;
        attribute preventsBackflow : Boolean = true;
    }

    part def GateValve {
        attribute type : String = "GateValve";
        attribute openFraction : Real = 1.0;
        port inletPort : DischargeFluidPort;
        port outletPort : DischargeFluidPort;
    }

    part def PressureSwitch {
        attribute lowerSetPoint : Pressure = 200000 [Pa];
        attribute upperSetPoint : Pressure = 350000 [Pa];
        attribute measuredPressure : Pressure;

        port sensingPort : PressureSensingPort;
        port controlPort : ControlPort;

        action def MonitorPressure {
            in pressure : Pressure;
            decision PressureCheck;
            if pressure < lowerSetPoint then SendStartSignal
            else if pressure >= upperSetPoint then SendStopSignal
            else ContinueMonitoring;
            action SendStartSignal {
                out signal : ControlSignal;
            }
            action SendStopSignal {
                out signal : ControlSignal;
            }
            action ContinueMonitoring;
        }
    }

    part def MotorStarter {
        attribute ratedPower : ElectricPower = 7500 [W];
        port powerIn : ElectricalPort;
        port powerOut : ElectricalPort;
        port controlPort : ControlPort;
    }

    part def OverloadRelay {
        attribute tripCurrent : Real = 20.0;
        attribute tripped : Boolean = false;
        port controlPort : ControlPort;
    }

    part def ControlPanel {
        attribute enclosureType : String = "NEMA4";
        port powerIn : ElectricalPort;
        port motorPowerOut : ElectricalPort;
        port pressureSensingIn : PressureSensingPort;
        port controlOut : ControlPort;

        part motorStarter : MotorStarter;
        part overloadRelay : OverloadRelay;
        part pressureSwitch : PressureSwitch;

        connection powerPassThrough connect powerIn to motorStarter.powerIn;
        connection motorPower connect motorStarter.powerOut to motorPowerOut;
        connection overloadControl connect motorStarter.controlPort to overloadRelay.controlPort;
        connection pressureInput connect pressureSensingIn to pressureSwitch.sensingPort;
        connection pressureControl connect pressureSwitch.controlPort to motorStarter.controlPort;
    }

    part def WaterSource {
        attribute type : String = "Reservoir";
        attribute waterLevel : Length = 2.0 [m];
        port outletPort : SuctionFluidPort;
    }

    part def IrrigationField {
        attribute name : String = "A.M. Bohnert Rice Plantation";
        attribute area : Real = 50.0;
        attribute cropType : String = "Rice";
        port inletPort : DischargeFluidPort;
    }

    // ---- Top-level System ----
    part def IrrigationPumpingSystem {
        attribute deliveredFlowRate : FlowRate;
        attribute deliveredPressure : Pressure;

        port systemPowerIn : ElectricalPort;
        port fieldDeliveryPort : DischargeFluidPort;

        part waterSource : WaterSource;
        part suctionPipe : SuctionPipe;
        part strainer : Strainer;
        part footValve : FootValve;
        part pump : CentrifugalPump;
        part motor : ElectricMotor;
        part controlPanel : ControlPanel;
        part checkValve : CheckValve;
        part gateValve : GateValve;
        part dischargePipe : DischargePipe;
        part irrigationField : IrrigationField;

        // Suction side connections
        connection sourceToSuction connect waterSource.outletPort to suctionPipe.inletPort;
        connection suctionToStrainer connect suctionPipe.outletPort to strainer.inletPort;
        connection strainerToFootValve connect strainer.outletPort to footValve.inletPort;
        connection footValveToPump connect footValve.outletPort to pump.suctionPort;

        // Drive connection
        connection motorToPumpDrive connect motor.drivePort to pump.drivePort;

        // Discharge side connections
        connection pumpToCheckValve connect pump.dischargePort to checkValve.inletPort;
        connection checkValveToGateValve connect checkValve.outletPort to gateValve.inletPort;
        connection gateValveToDischarge connect gateValve.outletPort to dischargePipe.inletPort;
        connection dischargeToField connect dischargePipe.outletPort to irrigationField.inletPort;

        // Control connections
        connection powerToPanel connect systemPowerIn to controlPanel.powerIn;
        connection panelToMotorPower connect controlPanel.motorPowerOut to motor.powerPort;
        connection panelToMotorControl connect controlPanel.controlOut to motor.controlPort;
        connection pumpPressureSensing connect pump.dischargePort to controlPanel.pressureSensingIn;
        connection fieldDelivery connect dischargePipe.outletPort to fieldDeliveryPort;

        // Requirement satisfaction
        satisfy IrrigationRequirement by pumpingSystem;
        satisfy PumpReliabilityRequirement by pump;
        satisfy MotorPowerRequirement by motor;
        satisfy AutomationRequirement by controlPanel;
    }

    part pumpingSystem : IrrigationPumpingSystem;

}
