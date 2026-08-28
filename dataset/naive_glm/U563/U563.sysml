package IndustrialSlurryPumpingSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ================================================
    // Value Type Definitions
    // ================================================

    value type SolidContentFraction :> Real {
        doc { /* Fraction of solids by mass in slurry mixture */ }
        attribute unit : String = "fraction";
        attribute maxValue : Real = 0.45;
    }

    value type FlowRateMeasure :> Real {
        doc { /* Volumetric flow rate in cubic meters per hour */ }
        attribute unit : String = "m^3/h";
    }

    value type PressureMeasure :> Real {
        doc { /* Fluid pressure in bar */ }
        attribute unit : String = "bar";
    }

    value type VolumeMeasure :> Real {
        doc { /* Volume in cubic meters */ }
        attribute unit : String = "m^3";
    }

    value type LengthMeasure :> Real {
        doc { /* Length in meters */ }
        attribute unit : String = "m";
    }

    value type VoltageMeasure :> Real {
        doc { /* Electrical voltage in volts */ }
        attribute unit : String = "V";
    }

    value type FrequencyMeasure :> Real {
        doc { /* Frequency in hertz */ }
        attribute unit : String = "Hz";
    }

    value type DurationMeasure :> Real {
        doc { /* Duration in hours */ }
        attribute unit : String = "h";
    }

    value type RotationalSpeedMeasure :> Real {
        doc { /* Rotational speed in revolutions per minute */ }
        attribute unit : String = "RPM";
    }

    value type CurrentMeasure :> Real {
        doc { /* Electric current in amperes */ }
        attribute unit : String = "A";
    }

    value type PipeDiameter :> Real {
        doc { /* Internal pipe diameter in meters */ }
        attribute unit : String = "m";
    }

    value type MassDensity :> Real {
        doc { /* Bulk density in kilograms per cubic meter */ }
        attribute unit : String = "kg/m^3";
    }

    value type ViscosityMeasure :> Real {
        doc { /* Apparent viscosity in centipoise */ }
        attribute unit : String = "cP";
    }

    // ================================================
    // Item Definitions
    // ================================================

    item def Slurry {
        doc { /* Abrasive mixture of solids and liquids for industrial transfer */ }
        attribute solidContent : SolidContentFraction;
        attribute bulkDensity : MassDensity;
        attribute apparentViscosity : ViscosityMeasure;
        constraint solidContentLimit { solidContent <= 0.45; }
    }

    // ================================================
    // Port Definitions
    // ================================================

    port def FluidPort {
        doc { /* Port for slurry fluid flow with associated flow rate and pressure */ }
        item slurry : Slurry;
        attribute flowRate : FlowRateMeasure;
        attribute pressure : PressureMeasure;
    }

    port def PowerPort {
        doc { /* Port for three-phase electrical power transmission */ }
        attribute voltage : VoltageMeasure;
        attribute current : CurrentMeasure;
        attribute energized : Boolean;
    }

    port def ControlPort {
        doc { /* Port for command and control signal interface */ }
        attribute startCommand : Boolean;
        attribute stopCommand : Boolean;
        attribute resetCommand : Boolean;
        attribute speedSetpoint : Real;
    }

    port def MeasurementPort {
        doc { /* Port for sensor measurement data output */ }
        attribute measuredValue : Real;
        attribute measurementValid : Boolean;
        attribute faultFlag : Boolean;
    }

    // ================================================
    // Part Definitions
    // ================================================

    part def PowerSupply {
        doc { /* Industrial three-phase electrical power supply */ }
        attribute ratedVoltage : VoltageMeasure;
        attribute ratedCurrent : CurrentMeasure;
        attribute phaseCount : Integer = 3;
        port powerOut : PowerPort;
    }

    part def SourceTank {
        doc { /* Storage tank holding slurry at the source location */ }
        attribute capacity : VolumeMeasure;
        attribute currentLevel : VolumeMeasure;
        attribute minOperatingLevel : VolumeMeasure;
        attribute maxFillLevel : VolumeMeasure;
        port fluidOut : FluidPort;
    }

    part def DestinationTank {
        doc { /* Receiving tank for transferred slurry at destination */ }
        attribute capacity : VolumeMeasure;
        attribute currentLevel : VolumeMeasure;
        attribute maxLevel : VolumeMeasure;
        port fluidIn : FluidPort;
    }

    part def HardenedSteelPipe {
        doc { /* Hardened steel pipe section for abrasive slurry transport */ }
        attribute material : String = "HardenedSteel";
        attribute length : LengthMeasure;
        attribute innerDiameter : PipeDiameter;
        attribute wallThickness : Real;
        attribute abrasionResistanceRating : String;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
    }

    part def FlowMeter {
        doc { /* Inline electromagnetic flow meter for slurry flow measurement */ }
        attribute measurementRange : FlowRateMeasure;
        attribute accuracy : Real;
        attribute linerMaterial : String = "HardenedRubber";
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port measurementOut : MeasurementPort;
    }

    part def PressureSensor {
        doc { /* Pressure transducer for slurry pipeline pressure monitoring */ }
        attribute measurementRange : PressureMeasure;
        attribute accuracyGrade : Real;
        port fluidTap : FluidPort;
        port measurementOut : MeasurementPort;
    }

    part def VariableFrequencyDrive {
        doc { /* Variable frequency drive for adjustable motor speed control */ }
        attribute outputFrequency : FrequencyMeasure;
        attribute minFrequency : FrequencyMeasure;
        attribute maxFrequency : FrequencyMeasure;
        attribute ratedPowerKW : Real;
        attribute overloadCapacity : Real;
        port powerIn : PowerPort;
        port powerOut : PowerPort;
        port controlIn : ControlPort;
    }

    part def MotorController {
        doc { /* Motor controller integrating VFD for pump speed regulation */ }
        attribute targetSpeed : RotationalSpeedMeasure;
        attribute protectionEnabled : Boolean = true;
        part vfd : VariableFrequencyDrive;
        port powerIn : PowerPort;
        port powerOut : PowerPort;
        port commandIn : ControlPort;
        port pumpControl : ControlPort;

        connect powerIn to vfd.powerIn;
        connect vfd.powerOut to powerOut;
        connect commandIn to vfd.controlIn;
        connect commandIn to pumpControl;
    }

    part def SlurryPump {
        doc { /* Heavy-duty centrifugal slurry pump for high solid content fluids */ }
        attribute ratedFlowRate : FlowRateMeasure;
        attribute ratedDischargePressure : PressureMeasure;
        attribute maxSolidContent : SolidContentFraction;
        attribute currentSpeed : RotationalSpeedMeasure;
        attribute operating : Boolean;
        attribute impellerDiameter : PipeDiameter;
        attribute impellerMaterial : String = "HardenedSteel";
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port powerIn : PowerPort;
        port controlIn : ControlPort;
    }

    // ================================================
    // Top-level System Part
    // ================================================

    part SlurryPumpingSystem {
        doc { /* Complete industrial slurry pumping system for abrasive slurry transfer */ }

        attribute maintenanceInterval : DurationMeasure = 8000;
        attribute targetFlowRate : FlowRateMeasure = 200;
        attribute maxDesignSolidContent : SolidContentFraction = 0.45;
        attribute systemAvailability : Real;

        port commandIn : ControlPort;

        // --- Power Subsystem ---

        part powerSupply : PowerSupply {
            override attribute ratedVoltage = 480;
            override attribute ratedCurrent = 300;
            override attribute phaseCount = 3;
        }

        // --- Control Subsystem ---

        part motorController : MotorController {
            override attribute targetSpeed = 1480;
            override part vfd : VariableFrequencyDrive {
                override attribute minFrequency = 0;
                override attribute maxFrequency = 50;
                override attribute ratedPowerKW = 75;
                override attribute overloadCapacity = 1.5;
            }
        }

        // --- Pump ---

        part pump : SlurryPump {
            override attribute ratedFlowRate = 200;
            override attribute ratedDischargePressure = 10;
            override attribute maxSolidContent = 0.45;
            override attribute currentSpeed = 0;
            override attribute operating = false;
            override attribute impellerDiameter = 0.35;
            override attribute impellerMaterial = "HardenedSteel";
        }

        // --- Tanks ---

        part sourceTank : SourceTank {
            override attribute capacity = 50;
            override attribute currentLevel = 40;
            override attribute minOperatingLevel = 5;
            override attribute maxFillLevel = 48;
        }

        part destinationTank : DestinationTank {
            override attribute capacity = 75;
            override attribute currentLevel = 10;
            override attribute maxLevel = 70;
        }

        // --- Suction Piping ---

        part suctionPipe : HardenedSteelPipe {
            override attribute material = "HardenedSteel";
            override attribute length = 15;
            override attribute innerDiameter = 0.20;
            override attribute wallThickness = 0.010;
            override attribute abrasionResistanceRating = "AR500";
        }

        // --- Discharge Piping ---

        part dischargePipe : HardenedSteelPipe {
            override attribute material = "HardenedSteel";
            override attribute length = 25;
            override attribute innerDiameter = 0.15;
            override attribute wallThickness = 0.012;
            override attribute abrasionResistanceRating = "AR500";
        }

        // --- Suction Sensors ---

        part suctionFlowMeter : FlowMeter {
            override attribute measurementRange = 300;
            override attribute accuracy = 0.02;
            override attribute linerMaterial = "HardenedRubber";
        }

        part suctionPressureSensor : PressureSensor {
            override attribute measurementRange = 5;
            override attribute accuracyGrade = 0.5;
        }

        // --- Discharge Sensors ---

        part dischargeFlowMeter : FlowMeter {
            override attribute measurementRange = 300;
            override attribute accuracy = 0.02;
            override attribute linerMaterial = "HardenedRubber";
        }

        part dischargePressureSensor : PressureSensor {
            override attribute measurementRange = 20;
            override attribute accuracyGrade = 0.5;
        }

        // ============================================
        // Connections - Fluid Path
        // ============================================

        connect sourceTank.fluidOut to suctionPipe.fluidIn;
        connect suctionPipe.fluidOut to suctionFlowMeter.fluidIn;
        connect suctionFlowMeter.fluidOut to pump.fluidIn;
        connect suctionPressureSensor.fluidTap to pump.fluidIn;
        connect pump.fluidOut to dischargePipe.fluidIn;
        connect dischargePressureSensor.fluidTap to pump.fluidOut;
        connect dischargePipe.fluidOut to dischargeFlowMeter.fluidIn;
        connect dischargeFlowMeter.fluidOut to destinationTank.fluidIn;

        // ============================================
        // Connections - Power Path
        // ============================================

        connect powerSupply.powerOut to motorController.powerIn;
        connect motorController.powerOut to pump.powerIn;

        // ============================================
        // Connections - Control Path
        // ============================================

        connect commandIn to motorController.commandIn;
        connect motorController.pumpControl to pump.controlIn;

        // ============================================
        // State Machine
        // ============================================

        state operatingStateMachine {
            doc { /* Governs the operational states of the slurry pumping system */ }

            state stopped {
                doc { /* System stopped: motor de-energized, no flow, safe state */ }
                entry {
                    pump.operating = false;
                    pump.currentSpeed = 0;
                }
            }

            state starting {
                doc { /* Startup sequence: VFD ramping pump speed to operating setpoint */ }
                entry {
                    pump.operating = true;
                }
                do {
                    /* VFD ramps output frequency from 0 Hz to operating frequency
                       while monitoring suction pressure for adequate priming */
                }
            }

            state running {
                doc { /* Normal operation maintaining target flow rate of 200 m^3/h */ }
                entry {
                    /* Confirm stable flow at target rate and all sensors nominal */
                }
                do {
                    /* Continuously monitor suction and discharge sensors,
                       maintain steady-state flow, update controller setpoints */
                }
            }

            state stopping {
                doc { /* Controlled shutdown: ramping pump speed to zero */ }
                entry {
                    /* Initiate VFD ramp-down sequence */
                }
                do {
                    /* Ramp VFD output frequency to 0 Hz,
                       verify flow decay to zero */
                }
            }

            state faulted {
                doc { /* Fault detected: pump emergency stopped, manual reset required */ }
                entry {
                    pump.operating = false;
                    pump.currentSpeed = 0;
                    /* Activate alarm indicator, lock out restart */
                }
                do {
                    /* Await manual reset command; no automatic recovery permitted */
                }
            }

            // Normal transitions
            transition startCommand
                from stopped to starting
                when commandIn.startCommand == true;

            transition reachedTargetFlow
                from starting to running
                when pump.fluidOut.flowRate >= 180;

            transition stopCommand
                from running to stopping
                when commandIn.stopCommand == true;

            transition pumpDecelerated
                from stopping to stopped
                when pump.fluidOut.flowRate <= 5;

            // Fault transitions
            transition suctionPressureFaultDuringStart
                from starting to faulted
                when suctionPressureSensor.measurementOut.measuredValue < 0.5;

            transition dischargeFlowHighFault
                from running to faulted
                when dischargeFlowMeter.measurementOut.measuredValue > 250;

            transition dischargePressureHighFault
                from running to faulted
                when dischargePressureSensor.measurementOut.measuredValue > 15;

            transition suctionFlowLowFault
                from running to faulted
                when suctionFlowMeter.measurementOut.measuredValue < 50;

            // Reset transition (manual reset required)
            transition manualReset
                from faulted to stopped
                when commandIn.resetCommand == true
                    and commandIn.startCommand == false;
        }

        // System-level constraints
        constraint flowRateTargetMet { pump.fluidOut.flowRate >= 190 and pump.fluidOut.flowRate <= 210; }
        constraint solidContentWithinLimit { pump.maxSolidContent <= 0.45; }
    }

    // ================================================
    // Requirement Definitions
    // ================================================

    req def SlurryTransferReq {
        doc { /* System shall transfer abrasive slurry from a 50 m^3 source tank to a 75 m^3 destination tank */ }
        attribute sourceTankCapacity : VolumeMeasure = 50;
        attribute destinationTankCapacity : VolumeMeasure = 75;
    }

    req def SolidContentHandlingReq {
        doc { /* Pump shall handle slurry with solid content up to 45 percent by mass */ }
        attribute maxSolidContent : SolidContentFraction = 0.45;
    }

    req def NominalFlowRateReq {
        doc { /* System shall achieve a nominal flow rate of approximately 200 m^3/h */ }
        attribute nominalFlow : FlowRateMeasure = 200;
    }

    req def PowerSupplyVoltageReq {
        doc { /* System shall be powered by a 480 V industrial power supply */ }
        attribute supplyVoltage : VoltageMeasure = 480;
    }

    req def VFDControlReq {
        doc { /* Pump speed shall be controlled by a variable frequency drive within the motor controller */ }
    }

    req def HardenedSteelPipeReq {
        doc { /* All slurry piping shall be constructed of hardened steel for abrasion resistance */ }
        attribute material : String = "HardenedSteel";
    }

    req def SuctionPipeLengthReq {
        doc { /* Suction piping shall be 15 meters in length */ }
        attribute requiredLength : LengthMeasure = 15;
    }

    req def DischargePipeLengthReq {
        doc { /* Discharge piping shall be 25 meters in length */ }
        attribute requiredLength : LengthMeasure = 25;
    }

    req def MonitoringReq {
        doc { /* Flow rate and pressure shall be monitored on both suction and discharge sides of the pump */ }
    }

    req def OperatingStatesReq {
        doc { /* System shall operate in five distinct states: stopped, starting, running, stopping, and faulted */ }
    }

    req def FaultSafetyReq {
        doc { /* Upon fault detection the pump shall shut down automatically and require a manual reset before resuming */ }
    }

    req def MaintenanceIntervalReq {
        doc { /* System shall be designed for continuous operation of 8000 hours between scheduled maintenance periods */ }
        attribute requiredInterval : DurationMeasure = 8000;
    }

    // ================================================
    // Requirement Usages
    // ================================================

    requirement slurryTransferRequirement : SlurryTransferReq;
    requirement solidContentRequirement : SolidContentHandlingReq;
    requirement flowRateRequirement : NominalFlowRateReq;
    requirement powerSupplyRequirement : PowerSupplyVoltageReq;
    requirement vfdControlRequirement : VFDControlReq;
    requirement pipeMaterialRequirement : HardenedSteelPipeReq;
    requirement suctionPipeLengthRequirement : SuctionPipeLengthReq;
    requirement dischargePipeLengthRequirement : DischargePipeLengthReq;
    requirement monitoringRequirement : MonitoringReq;
    requirement operatingStatesRequirement : OperatingStatesReq;
    requirement faultSafetyRequirement : FaultSafetyReq;
    requirement maintenanceIntervalRequirement : MaintenanceIntervalReq;

    // ================================================
    // Satisfaction Relationships
    // ================================================

    satisfy slurryTransferRequirement by SlurryPumpingSystem;
    satisfy solidContentRequirement by SlurryPumpingSystem.pump;
    satisfy flowRateRequirement by SlurryPumpingSystem.pump;
    satisfy powerSupplyRequirement by SlurryPumpingSystem.powerSupply;
    satisfy vfdControlRequirement by SlurryPumpingSystem.motorController;
    satisfy pipeMaterialRequirement by SlurryPumpingSystem.suctionPipe;
    satisfy pipeMaterialRequirement by SlurryPumpingSystem.dischargePipe;
    satisfy suctionPipeLengthRequirement by SlurryPumpingSystem.suctionPipe;
    satisfy dischargePipeLengthRequirement by SlurryPumpingSystem.dischargePipe;
    satisfy monitoringRequirement by SlurryPumpingSystem.suctionFlowMeter;
    satisfy monitoringRequirement by SlurryPumpingSystem.suctionPressureSensor;
    satisfy monitoringRequirement by SlurryPumpingSystem.dischargeFlowMeter;
    satisfy monitoringRequirement by SlurryPumpingSystem.dischargePressureSensor;
    satisfy operatingStatesRequirement by SlurryPumpingSystem;
    satisfy faultSafetyRequirement by SlurryPumpingSystem;
    satisfy maintenanceIntervalRequirement by SlurryPumpingSystem;
}
