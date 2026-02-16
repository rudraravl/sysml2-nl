package PeristalticPumpSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import NumericalFunctions::*;

    attribute def VolumeFlowRateValue {
        attribute num : Real;
        attribute unit : VolumePerTimeUnit;
    }

    attribute def PressureValue {
        attribute num : Real;
        attribute unit : PressureUnit;
    }

    attribute def AngularVelocityValue {
        attribute num : Real;
        attribute unit : AnglePerTimeUnit;
    }

    attribute def TubeSegmentState {
        attribute isCompressed : Boolean;
        attribute compressionDepth : LengthValue;
        attribute segmentVolume : VolumeValue;
    }

    enum def OperationalMode {
        stopped;
        priming;
        running;
        reversing;
        faulted;
    }

    item def Fluid {
        attribute volume : VolumeValue;
        attribute viscosity : Real;
        attribute density : Real;
        attribute temperature : TemperatureValue;
    }

    port def FluidPort {
        attribute flowRate : VolumeFlowRateValue;
        attribute pressure : PressureValue;
        inout item fluid : Fluid;
    }

    part def FlexibleTube {
        attribute innerDiameter : LengthValue;
        attribute outerDiameter : LengthValue;
        attribute wallThickness : LengthValue;
        attribute elasticModulus : Real;
        attribute tubeLength : LengthValue;
        attribute numberOfSegments : Integer = 12;

        port inlet : FluidPort;
        port outlet : FluidPort;

        part segments : TubeSegmentState[numberOfSegments];
    }

    part def CompressionRoller {
        attribute rollerDiameter : LengthValue;
        attribute rollerWidth : LengthValue;
        attribute angularPosition : Real;
        attribute compressionForce : ForceValue;

        perform action compressTube {
            in tubeSegment : TubeSegmentState;
            out compressedSegment : TubeSegmentState;
            out displacedVolume : VolumeValue;
        }
    }

    part def RotorAssembly {
        attribute numberOfRollers : Integer = 3;
        attribute rotorDiameter : LengthValue;
        attribute angularVelocity : AngularVelocityValue;
        attribute currentAngle : Real;

        part rollers : CompressionRoller[numberOfRollers];

        perform action rotateRollers {
            in speed : AngularVelocityValue;
            out rollerPositions : Real[numberOfRollers];
        }
    }

    part def DriveMotor {
        attribute nominalSpeed : AngularVelocityValue;
        attribute currentSpeed : AngularVelocityValue;
        attribute torque : Real;
        attribute power : PowerValue;
        attribute efficiency : Real;

        port powerInput;
        port mechanicalOutput;
        port controlSignal;

        perform action adjustSpeed {
            in targetSpeed : AngularVelocityValue;
            out actualSpeed : AngularVelocityValue;
        }
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        attribute measurementAccuracy : Real;
        attribute responseTime : TimeValue;

        port sensingPoint : FluidPort;
        port dataOutput;
    }

    part def FlowRateSensor {
        attribute measuredFlowRate : VolumeFlowRateValue;
        attribute measurementAccuracy : Real;
        attribute responseTime : TimeValue;

        port sensingPoint : FluidPort;
        port dataOutput;
    }

    part def PumpController {
        attribute targetFlowRate : VolumeFlowRateValue;
        attribute currentMode : OperationalMode;
        attribute maxPressureLimit : PressureValue;
        attribute minFlowRate : VolumeFlowRateValue;
        attribute maxFlowRate : VolumeFlowRateValue;

        port sensorInputs[*];
        port motorControlOutput;
        port userInterface;

        perform action regulateFlow {
            in desiredFlow : VolumeFlowRateValue;
            in actualFlow : VolumeFlowRateValue;
            in currentPressure : PressureValue;
            out motorSpeed : AngularVelocityValue;
        }

        perform action detectOcclusion {
            in pressure : PressureValue;
            in flowRate : VolumeFlowRateValue;
            out occlusionDetected : Boolean;
        }
    }

    part def FluidReservoir {
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        attribute minimumLevel : VolumeValue;

        port fluidOutlet : FluidPort;

        assert constraint levelCheck {
            currentLevel.num >= minimumLevel.num
        }
    }

    part def DeliveryLine {
        attribute lineLength : LengthValue;
        attribute lineDiameter : LengthValue;
        attribute maxPressure : PressureValue;

        port inlet : FluidPort;
        port outlet : FluidPort;
    }

    action def PeristalticPumpingCycle {
        in controllerRef : PumpController;
        
        first start;
        then merge cycleBegin;

        then action positionRollers {
            out roller1Angle : Real;
            out roller2Angle : Real;
            out roller3Angle : Real;
        }

        then action compressSegment1 {
            in rollerAngle = positionRollers.roller1Angle;
            out segment1State : TubeSegmentState;
            out volumeDisplaced1 : VolumeValue;
        }

        then action compressSegment2 {
            in rollerAngle = positionRollers.roller2Angle;
            out segment2State : TubeSegmentState;
            out volumeDisplaced2 : VolumeValue;
        }

        then action compressSegment3 {
            in rollerAngle = positionRollers.roller3Angle;
            out segment3State : TubeSegmentState;
            out volumeDisplaced3 : VolumeValue;
        }

        then action advanceFluid {
            in vol1 = compressSegment1.volumeDisplaced1;
            in vol2 = compressSegment2.volumeDisplaced2;
            in vol3 = compressSegment3.volumeDisplaced3;
            out totalVolumeAdvanced : VolumeValue;
        }

        then action releaseSegments {
            in seg1 = compressSegment1.segment1State;
            in seg2 = compressSegment2.segment2State;
            in seg3 = compressSegment3.segment3State;
            out relaxedSegments : TubeSegmentState[3];
        }

        then action refillSegments {
            in relaxed = releaseSegments.relaxedSegments;
            out refilledSegments : TubeSegmentState[3];
        }

        then decide;
            if controllerRef.currentMode == OperationalMode::running then cycleBegin;
            if controllerRef.currentMode == OperationalMode::stopped then stopPumping;

        action stopPumping;
        then done;
    }

    state def PumpOperationStateMachine {
        in controllerRef : PumpController;
        
        entry; then idle;

        state idle;
        then priming
            accept startPriming;

        state priming {
            do action primeTube {
                out tubeReady : Boolean;
            }
        }
        then running
            accept primingComplete;

        state running {
            do action continuousPumping : PeristalticPumpingCycle {
                in controllerRef = controllerRef;
            }
        }
        then paused
            accept pauseCommand;
        then faulted
            accept occlusionDetected;

        state paused;
        then running
            accept resumeCommand;
        then idle
            accept stopCommand;

        state faulted {
            do action handleFault {
                out faultCleared : Boolean;
            }
        }
        then idle
            accept faultReset;
    }

    part def PeristalticPump {
        doc /* A peristaltic pump that transfers fluid by sequential compression of a flexible tube,
             * creating a wave-like peristaltic motion that propels fluid without direct contact
             * between the pumping mechanism and the fluid being transferred.
             */

        attribute operatingFlowRate : VolumeFlowRateValue;
        attribute maxOperatingPressure : PressureValue;
        attribute tubeCompressionRatio : Real;
        attribute pumpEfficiency : Real;

        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        port electricalPower;

        part tube : FlexibleTube {
            attribute :>> innerDiameter = 6.35 [mm];
            attribute :>> outerDiameter = 9.53 [mm];
            attribute :>> wallThickness = 1.59 [mm];
            attribute :>> elasticModulus = 0.75;
            attribute :>> tubeLength = 150.0 [mm];
            attribute :>> numberOfSegments = 12;
        }

        part rotor : RotorAssembly {
            attribute :>> numberOfRollers = 3;
            attribute :>> rotorDiameter = 80.0 [mm];
        }

        part motor : DriveMotor {
            attribute :>> power = 30.0 [W];
            attribute :>> efficiency = 0.85;
        }

        part controller : PumpController {
            attribute :>> currentMode = OperationalMode::stopped;
        }

        part inletPressureSensor : PressureSensor {
            attribute :>> measurementAccuracy = 0.015;
            attribute :>> responseTime = 0.1 [s];
        }

        part outletPressureSensor : PressureSensor {
            attribute :>> measurementAccuracy = 0.015;
            attribute :>> responseTime = 0.1 [s];
        }

        part flowSensor : FlowRateSensor {
            attribute :>> measurementAccuracy = 0.02;
            attribute :>> responseTime = 0.2 [s];
        }

        connection motorToRotor connect motor.mechanicalOutput to rotor;
        connection controllerToMotor connect controller.motorControlOutput to motor.controlSignal;
        connection inletSensorConnection connect inletPressureSensor.sensingPoint to tube.inlet;
        connection outletSensorConnection connect outletPressureSensor.sensingPoint to tube.outlet;
        connection flowSensorConnection connect flowSensor.sensingPoint to tube.outlet;
        connection sensorToController1 connect inletPressureSensor.dataOutput to controller.sensorInputs;
        connection sensorToController2 connect outletPressureSensor.dataOutput to controller.sensorInputs;
        connection sensorToController3 connect flowSensor.dataOutput to controller.sensorInputs;
        connection tubeInletConnection connect fluidInlet to tube.inlet;
        connection tubeOutletConnection connect tube.outlet to fluidOutlet;

        assert constraint flowRateCalculation {
            operatingFlowRate.num == rotor.angularVelocity.num * tube.innerDiameter.num * tube.innerDiameter.num * tubeCompressionRatio * 60.0 / 1000.0
        }

        assert constraint pressureDifferential {
            maxOperatingPressure.num == outletPressureSensor.measuredPressure.num - inletPressureSensor.measuredPressure.num
        }

        perform action pumpFluid : PeristalticPumpingCycle {
            in controllerRef = controller;
        }
        
        exhibit state pumpOperation : PumpOperationStateMachine {
            in controllerRef = controller;
        }
    }

    part peristalticPumpSystem : PeristalticPump {
        part sourceReservoir : FluidReservoir {
            attribute :>> capacity = 5000.0 [mL];
            attribute :>> currentLevel = 4200.0 [mL];
            attribute :>> minimumLevel = 500.0 [mL];
        }

        part deliveryLine : DeliveryLine {
            attribute :>> lineLength = 2000.0 [mm];
            attribute :>> lineDiameter = 6.0 [mm];
        }

        part transferredFluid : Fluid {
            attribute :>> volume = 200.0 [mL];
            attribute :>> viscosity = 1.5;
            attribute :>> density = 1050.0;
            attribute :>> temperature = 298.0 [K];
        }

        connection sourceConnection connect sourceReservoir.fluidOutlet to fluidInlet;
        connection deliveryConnection connect fluidOutlet to deliveryLine.inlet;

        attribute :>> tubeCompressionRatio = 0.65;
        attribute :>> pumpEfficiency = 0.78;

        perform pumpFluid;
    }

    requirement <'REQ-PUMP-001'> peristalticPumpingFunction {
        doc /* The peristaltic pump system shall transfer fluid by creating a progressive wave of 
             * compression along a flexible tube using rotating rollers, thereby propelling fluid 
             * from inlet to outlet through peristaltic action without direct mechanical contact 
             * between the pumping mechanism and the fluid.
             */
        subject pump :> peristalticPumpSystem;

        require flowRateCapability;
        require pressureCapability;
        require fluidIsolation;
        require sequentialCompression;
    }

    requirement <'REQ-PUMP-002'> flowRateCapability {
        doc /* The pump shall deliver a controllable flow rate between 10 mL/min and 500 mL/min. */
        subject pump :> peristalticPumpSystem;

        assert constraint {
            pump.operatingFlowRate.num >= pump.controller.minFlowRate.num and
            pump.operatingFlowRate.num <= pump.controller.maxFlowRate.num
        }
    }

    requirement <'REQ-PUMP-003'> pressureCapability {
        doc /* The pump shall operate at outlet pressures up to 250 kPa without tube failure or leakage. */
        subject pump :> peristalticPumpSystem;

        assert constraint {
            pump.maxOperatingPressure.num <= pump.controller.maxPressureLimit.num
        }
    }

    requirement <'REQ-PUMP-004'> fluidIsolation {
        doc /* The pumped fluid shall remain completely isolated within the flexible tube, 
             * preventing any contamination between the fluid and the pumping mechanism.
             */
        subject tube :> peristalticPumpSystem.tube;
    }

    requirement <'REQ-PUMP-005'> sequentialCompression {
        doc /* The pump shall use at least two compression rollers positioned sequentially 
             * to create continuous peristaltic motion along the tube.
             */
        subject rotor :> peristalticPumpSystem.rotor;

        assert constraint {
            rotor.numberOfRollers >= 2
        }
    }

    requirement <'REQ-PUMP-006'> reversibilityCapability {
        doc /* The pump shall support bidirectional flow by reversing the direction of rotor rotation. */
        subject pump :> peristalticPumpSystem;
    }

    requirement <'REQ-PUMP-007'> occlusionDetection {
        doc /* The pump controller shall detect downstream occlusions by monitoring pressure 
             * and flow rate, and shall enter a faulted state when occlusion is detected.
             */
        subject controller :> peristalticPumpSystem.controller;
    }

    satisfy peristalticPumpingFunction by peristalticPumpSystem;
    satisfy flowRateCapability by peristalticPumpSystem;
    satisfy pressureCapability by peristalticPumpSystem;
    satisfy fluidIsolation by peristalticPumpSystem.tube;
    satisfy sequentialCompression by peristalticPumpSystem.rotor;
}
