package WatermillSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def WaterFlowRate :> ISQ::VolumetricFlowRateValue {
        attribute :>> num : Real;
        attribute :>> mRef : VolumetricFlowRateUnit;
    }

    attribute def RotationalSpeed :> ISQ::AngularVelocityValue {
        attribute :>> num : Real;
        attribute :>> mRef : AngularVelocityUnit;
    }

    attribute def TorqueValue :> ISQ::TorqueValue {
        attribute :>> num : Real;
        attribute :>> mRef : TorqueUnit;
    }

    attribute def GrainMass :> ISQ::MassValue {
        attribute :>> num : Real;
        attribute :>> mRef : MassUnit;
    }

    item def WaterFlow {
        attribute flowRate : WaterFlowRate;
        attribute velocity : ISQ::SpeedValue;
        attribute head : ISQ::LengthValue;
    }

    item def MechanicalPower {
        attribute torque : TorqueValue;
        attribute rotationalSpeed : RotationalSpeed;
    }

    item def Grain {
        attribute grainType : String;
        attribute mass : GrainMass;
    }

    item def Flour {
        attribute fineness : ISQ::LengthValue;
        attribute mass : GrainMass;
    }

    port def WaterInletPort {
        in item waterFlow : WaterFlow;
    }

    port def WaterOutletPort {
        out item waterFlow : WaterFlow;
    }

    port def MechanicalPowerPort {
        inout item mechanicalPower : MechanicalPower;
    }

    port def GrainInputPort {
        in item grain : Grain;
    }

    port def FlourOutputPort {
        out item flour : Flour;
    }

    part def WaterWheel {
        attribute diameter : ISQ::LengthValue;
        attribute numberOfBuckets : Integer;
        attribute efficiency : Real;

        port waterInlet : WaterInletPort;
        port waterOutlet : WaterOutletPort;
        port mechanicalOutput : MechanicalPowerPort;

        perform action convertWaterToRotation {
            in incomingWater : WaterFlow;
            out outputPower : MechanicalPower;
            out exitingWater : WaterFlow;
        }
    }

    part def DriveShaft {
        attribute length : ISQ::LengthValue;
        attribute diameter : ISQ::LengthValue;
        attribute materialStrength : ISQ::PressureValue;

        port powerInput : MechanicalPowerPort;
        port powerOutput : MechanicalPowerPort;

        perform action transmitPower {
            in inputPower : MechanicalPower;
            out outputPower : MechanicalPower;
        }
    }

    part def Millstone {
        attribute outerDiameter : ISQ::LengthValue;
        attribute thickness : ISQ::LengthValue;
        attribute weight : ISQ::MassValue;
        attribute surfaceRoughness : ISQ::LengthValue;

        port powerInput : MechanicalPowerPort;
        port grainInput : GrainInputPort;
        port flourOutput : FlourOutputPort;

        perform action grindGrain {
            in power : MechanicalPower;
            in rawGrain : Grain;
            out processedFlour : Flour;
        }
    }

    part def WaterChannel {
        attribute slope : Real;
        attribute width : ISQ::LengthValue;
        attribute depth : ISQ::LengthValue;

        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;

        perform action directWater {
            in incomingFlow : WaterFlow;
            out directedFlow : WaterFlow;
        }
    }

    part def GrainHopper {
        attribute capacity : ISQ::VolumeValue;
        attribute currentLevel : Real;

        port grainInput : GrainInputPort;
        port grainOutput : GrainInputPort;

        perform action feedGrain {
            in storedGrain : Grain;
            out dispensedGrain : Grain;
        }
    }

    part def FlourCollector {
        attribute capacity : ISQ::VolumeValue;
        attribute currentLevel : Real;

        port flourInput : FlourOutputPort;
        port flourOutput : FlourOutputPort;

        perform action collectFlour {
            in incomingFlour : Flour;
            out storedFlour : Flour;
        }
    }

    connection def WaterFlowConnection {
        end source : WaterOutletPort;
        end target : WaterInletPort;
    }

    connection def PowerTransmissionConnection {
        end source : MechanicalPowerPort;
        end target : MechanicalPowerPort;
    }

    connection def GrainFlowConnection {
        end source : GrainInputPort;
        end target : GrainInputPort;
    }

    connection def FlourFlowConnection {
        end source : FlourOutputPort;
        end target : FlourOutputPort;
    }

    state def WatermillOperatingStates {
        in attribute waterFlowActive : Boolean;
        in attribute wheelSpeed : RotationalSpeed;
        in attribute minimumOperationalSpeed : RotationalSpeed;

        entry; then idle;

        state idle;

        transition idle_to_starting
            first idle
            if waterFlowActive
            then starting;

        state starting {
            entry; then accelerating;

            state accelerating;

            transition accelerating_to_operational
                first accelerating
                if wheelSpeed.num >= minimumOperationalSpeed.num
                then operational;
        }

        state operational {
            entry; then grinding;

            state grinding {
                do action processGrain;
            }

            state monitoring {
                do action monitorPerformance;
            }
        }

        transition operational_to_stopping
            first operational
            if not waterFlowActive
            then stopping;

        state stopping {
            entry; then decelerating;

            state decelerating;

            transition decelerating_to_idle
                first decelerating
                if wheelSpeed.num <= 0.0
                then idle;
        }
    }

    action def MonitorWaterFlow {
        in channel : WaterChannel;
        out flowDetected : Boolean;
        out currentFlow : WaterFlow;
    }

    action def ConvertHydraulicEnergy {
        in waterFlow : WaterFlow;
        in wheelDiameter : ISQ::LengthValue;
        in wheelEfficiency : Real;
        out mechanicalPower : MechanicalPower;
    }

    action def TransmitMechanicalPower {
        in inputPower : MechanicalPower;
        in shaftEfficiency : Real;
        out outputPower : MechanicalPower;
    }

    action def GrindGrainAction {
        in power : MechanicalPower;
        in rawGrain : Grain;
        in millstoneWeight : ISQ::MassValue;
        out processedFlour : Flour;
    }

    action def OperateWatermill {
        first start;
        then merge continueOperation;

        action monitorFlow : MonitorWaterFlow {
            out flowStatus : Boolean;
            out detectedFlow : WaterFlow;
        }

        then decide;
            if monitorFlow.flowStatus then convertEnergy;
            if not monitorFlow.flowStatus then shutdown;

        action convertEnergy : ConvertHydraulicEnergy {
            in waterFlow = monitorFlow.detectedFlow;
            out wheelPower : MechanicalPower;
        }

        then action transmitPower : TransmitMechanicalPower {
            in inputPower = convertEnergy.wheelPower;
            out shaftPower : MechanicalPower;
        }

        then action grindOperation : GrindGrainAction {
            in power = transmitPower.shaftPower;
            out flour : Flour;
        }

        then continueOperation;

        action shutdown;
        then done;
    }

    part def Watermill {
        doc /* A watermill is a mechanical system that harnesses the kinetic energy 
               of flowing water to perform mechanical work, primarily grinding grain 
               into flour through the rotation of millstones. */

        attribute minimumOperationalSpeed : RotationalSpeed;
        attribute wheelSpeed : RotationalSpeed;
        attribute waterFlowActive : Boolean;

        part waterChannel : WaterChannel {
            attribute :>> slope = 0.03;
            attribute :>> width = 2.5[m];
            attribute :>> depth = 1.2[m];
        }

        part waterWheel : WaterWheel {
            attribute :>> diameter = 6.0[m];
            attribute :>> numberOfBuckets = 32;
            attribute :>> efficiency = 0.80;

            perform watermill.millOperation.convertEnergy;
        }

        part driveShaft : DriveShaft {
            attribute :>> length = 4.0[m];
            attribute :>> diameter = 0.35[m];

            perform watermill.millOperation.transmitPower;
        }

        part grainHopper : GrainHopper {
            attribute :>> capacity = 1.0[m^3];
            attribute :>> currentLevel = 0.75;

            perform action feedGrain;
        }

        part upperMillstone : Millstone {
            attribute :>> outerDiameter = 1.8[m];
            attribute :>> thickness = 0.30[m];
            attribute :>> weight = 1200.0[kg];

            perform watermill.millOperation.grindOperation;
        }

        part lowerMillstone : Millstone {
            attribute :>> outerDiameter = 1.8[m];
            attribute :>> thickness = 0.30[m];
            attribute :>> weight = 1250.0[kg];
        }

        part flourCollector : FlourCollector {
            attribute :>> capacity = 0.8[m^3];
            attribute :>> currentLevel = 0.25;

            perform action collectFlour;
        }

        connection waterChannelToWheel : WaterFlowConnection
            connect waterChannel.outlet to waterWheel.waterInlet;

        connection wheelToShaft : PowerTransmissionConnection
            connect waterWheel.mechanicalOutput to driveShaft.powerInput;

        connection shaftToMillstone : PowerTransmissionConnection
            connect driveShaft.powerOutput to upperMillstone.powerInput;

        connection hopperToMillstone : GrainFlowConnection
            connect grainHopper.grainOutput to upperMillstone.grainInput;

        connection millstoneToCollector : FlourFlowConnection
            connect upperMillstone.flourOutput to flourCollector.flourInput;

        perform action millOperation : OperateWatermill;

        exhibit state operatingStates : WatermillOperatingStates {
            in waterFlowActive = watermill.waterFlowActive;
            in wheelSpeed = watermill.wheelSpeed;
            in minimumOperationalSpeed = watermill.minimumOperationalSpeed;
        }
    }

    requirement def WatermillFunctionalRequirements {
        doc /* The watermill shall convert the kinetic energy of flowing water into 
               mechanical rotational energy to drive millstones for grinding grain into flour. */

        requirement <'WM-001'> primaryFunction {
            doc /* The watermill shall grind grain into flour using water power. */

            subject watermill : Watermill;

            require constraint {
                watermill.waterWheel.efficiency >= 0.70
            }
        }

        requirement <'WM-002'> continuousOperation {
            doc /* The watermill shall operate continuously while water flow is available 
                   and grain is being supplied. */

            subject watermill : Watermill;

            assume constraint sufficientWaterFlow {
                watermill.waterChannel.inlet.waterFlow.flowRate.num >= 0.5
            }

            require constraint maintainRotation {
                watermill.waterWheel.mechanicalOutput.mechanicalPower.rotationalSpeed.num > 0.0
            }
        }

        requirement <'WM-003'> grindingCapacity {
            doc /* The watermill shall process a minimum quantity of grain per hour 
                   under normal operating conditions. */

            subject watermill : Watermill;

            require constraint minimumThroughput {
                watermill.upperMillstone.flourOutput.flour.mass.num >= 50.0
            }
        }

        requirement <'WM-004'> safetyRequirement {
            doc /* The watermill shall automatically stop grinding operations when 
                   water flow ceases to prevent damage to the millstones. */

            subject watermill : Watermill;

            require constraint automaticShutdown {
                watermill.waterChannel.inlet.waterFlow.flowRate.num == 0.0 implies
                watermill.wheelSpeed.num == 0.0
            }
        }
    }

    part watermill : Watermill {
        attribute :>> minimumOperationalSpeed = 5.0[rad/s];
        attribute :>> wheelSpeed = 0.0[rad/s];
        attribute :>> waterFlowActive = false;
    }

    requirement watermillSystemRequirements : WatermillFunctionalRequirements;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import WatermillSystem::*;

    part testSubject : Watermill {
        exhibit state operatingStates : WatermillOperatingStates;
    }

    action orchestrator {
        action monitorFlowProbe : MonitorWaterFlow {
            // TODO(human): unsupported input type for channel: WaterChannel (type is not a primitive, enum, extracted payload def, or known value type)
        }
        first monitorFlowProbe;
    }
}
