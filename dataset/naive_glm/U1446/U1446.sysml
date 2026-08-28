package MHD_Drive {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceAndTime::*;
    import ISQElectromagnetism::*;
    import ISQThermodynamics::*;

    // ---- Value Types ----
    def Velocity :> Speed;
    def MassFlowRate :> MassFlowRateValue;
    def ThrustForce :> Force;
    def MagneticFluxDensityValue :> MagneticFluxDensity;
    def ElectricCurrentValue :> ElectricCurrent;
    def ElectricVoltageValue :> ElectricVoltage;
    def TemperatureValue :> Temperature;
    def PowerValue :> Power;
    def CoolantFlowRate :> MassFlowRateValue;

    item def Seawater;
    item def Coolant;

    // ---- Port definitions ----
    port def SeawaterInPort {
        in item waterIn : Seawater;
    }
    port def SeawaterOutPort {
        out item waterOut : Seawater;
    }
    port def CoolantPort {
        out item coolantOut : Coolant;
        in item coolantReturn : Coolant;
    }
    port def ElectricPowerPort {
        in voltage : ElectricVoltageValue;
        out current : ElectricCurrentValue;
    }
    port def ControlSignalPort {
        in thrustCommand : Real;
        out statusFeedback : Real;
    }
    port def SensorDataPort {
        out measurement : Real;
    }
    port def MagneticFieldPort {
        out fluxDensity : MagneticFluxDensityValue;
    }

    // ---- Requirements ----
    requirement def PropulsionRequirement {
        doc "The MHD drive shall generate thrust without moving parts in the propulsion stream."
        attribute minThrust : ThrustForce = 1000.0 [N];
        subject drive : MHD_Drive::MHDSystem;
        require drive.thrustGenerated >= minThrust;
    }

    requirement def CryogenicRequirement {
        doc "The cryogenic cooling system shall maintain superconducting magnets at approximately 4 K."
        attribute targetTemp : TemperatureValue = 4.0 [K];
        subject cooling : MHD_Drive::CryogenicCoolingSystem;
        require cooling.suppliedTemperature <= targetTemp;
    }

    requirement def SilentOperationRequirement {
        doc "The MHD drive shall operate with minimal acoustic signature."
        attribute maxAcousticNoise : Real = 60.0;
        subject drive : MHD_Drive::MHDSystem;
        require drive.acousticNoise <= maxAcousticNoise;
    }

    // ---- Part definitions ----
    part def ThrustChannel {
        attribute length : Real = 8.0 [m];
        attribute crossSectionArea : Real = 1.0 [m^2];
        port seawaterIn : SeawaterInPort;
        port seawaterOut : SeawaterOutPort;
        attribute inletVelocity : Velocity;
        attribute outletVelocity : Velocity;
        attribute thrustGenerated : ThrustForce;
        flow waterFlow : Seawater from seawaterIn.waterIn to seawaterOut.waterOut;
    }

    part def SuperconductingMagnet {
        attribute fieldStrength : MagneticFluxDensityValue = 10.0 [T];
        attribute operatingTemperature : TemperatureValue = 4.0 [K];
        port fieldPort : MagneticFieldPort;
        port coolantConnection : CoolantPort;
        attribute energized : Boolean = false;
    }

    part def ElectrodeAssembly {
        attribute anodeVoltage : ElectricVoltageValue;
        attribute cathodeVoltage : ElectricVoltageValue;
        attribute driveCurrent : ElectricCurrentValue;
        port powerIn : ElectricPowerPort;
        attribute active : Boolean = false;
    }

    part def CryogenicCoolingSystem {
        attribute coolantTemperature : TemperatureValue = 4.0 [K];
        attribute flowRate : CoolantFlowRate = 0.5 [kg/s];
        attribute suppliedTemperature : TemperatureValue;
        port coolantSupply : CoolantPort;
        attribute running : Boolean = false;
    }

    part def PowerSupply {
        attribute maxOutputPower : PowerValue = 50000.0 [W];
        attribute outputVoltage : ElectricVoltageValue;
        attribute outputCurrent : ElectricCurrentValue;
        port powerOutput : ElectricPowerPort;
        port controlInput : ControlSignalPort;
        attribute active : Boolean = false;
    }

    part def FlowSensor {
        port seawaterMeasurement : SeawaterOutPort;
        port dataOut : SensorDataPort;
        attribute measuredFlowRate : MassFlowRate;
    }

    part def ThrustSensor {
        port dataOut : SensorDataPort;
        attribute measuredThrust : ThrustForce;
    }

    part def ControlUnit {
        port operatorCommand : ControlSignalPort;
        port magnetControl : ControlSignalPort;
        port electrodeControl : ControlSignalPort;
        port powerControl : ControlSignalPort;
        port flowSensorInput : SensorDataPort;
        port thrustSensorInput : SensorDataPort;
        attribute commandedThrust : Real;
        attribute systemStatus : String;

        state machine ControlStateMachine {
            entry;
            then initializing;

            state initializing {
                entry { systemStatus = "Cooling and energizing magnets"; }
                do send CoolantStartCmd to coolingSystem;
                do send MagnetEnergizeCmd to magnetArray;
                transition
                    first initializing
                    accept MagnetReady
                    then operational;
            }

            state operational {
                entry { systemStatus = "Active thrust generation"; }
                do send PowerEnableCmd to powerSupply;
                do send ElectrodeActivateCmd to electrodeAssembly;
                transition
                    first operational
                    accept ShutdownCmd
                    then shutdown;
                transition
                    first operational
                    accept FaultDetected
                    then shutdown;
            }

            state shutdown {
                entry { systemStatus = "Safe power-down"; }
                do send ElectrodeDeactivateCmd to electrodeAssembly;
                do send PowerDisableCmd to powerSupply;
                do send MagnetDeenergizeCmd to magnetArray;
                do send CoolantStopCmd to coolingSystem;
                transition
                    first shutdown
                    accept ShutdownComplete
                    then off;
            }

            state off;
        }
    }

    part def MHDSystem {
        attribute thrustGenerated : ThrustForce;
        attribute acousticNoise : Real;

        part channel : ThrustChannel;
        part magnetArray[2] : SuperconductingMagnet;
        part electrodeAssembly : ElectrodeAssembly;
        part coolingSystem : CryogenicCoolingSystem;
        part powerSupply : PowerSupply;
        part controlUnit : ControlUnit;
        part flowSensor : FlowSensor;
        part thrustSensor : ThrustSensor;

        // External interfaces
        port operatorInterface : ControlSignalPort;
        port vesselSeawaterIn : SeawaterInPort;
        port vesselSeawaterOut : SeawaterOutPort;

        // Connections
        connection seawaterIntake connect vesselSeawaterIn to channel.seawaterIn;
        connection seawaterExhaust connect channel.seawaterOut to vesselSeawaterOut;

        connection magnetCoolant1 connect coolingSystem.coolantSupply to magnetArray[1].coolantConnection;
        connection magnetCoolant2 connect coolingSystem.coolantSupply to magnetArray[2].coolantConnection;

        connection magneticField1 connect magnetArray[1].fieldPort to channel;
        connection magneticField2 connect magnetArray[2].fieldPort to channel;

        connection electrodePower connect powerSupply.powerOutput to electrodeAssembly.powerIn;

        connection controlToPower connect controlUnit.powerControl to powerSupply.controlInput;
        connection controlToMagnet connect controlUnit.magnetControl to magnetArray[1];
        connection controlToElectrode connect controlUnit.electrodeControl to electrodeAssembly;

        connection operatorToControl connect operatorInterface to controlUnit.operatorCommand;

        connection flowSensorMount connect channel.seawaterOut to flowSensor.seawaterMeasurement;
        connection flowSensorData connect flowSensor.dataOut to controlUnit.flowSensorInput;

        connection thrustSensorData connect thrustSensor.dataOut to controlUnit.thrustSensorInput;

        // Requirements satisfaction
        satisfy PropulsionRequirement { subject = MHDSystem; }
        satisfy CryogenicRequirement { subject = coolingSystem; }
        satisfy SilentOperationRequirement { subject = MHDSystem; }
    }
}
