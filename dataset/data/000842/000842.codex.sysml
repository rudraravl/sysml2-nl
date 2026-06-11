package AirliftPumpingSubsystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value def Pressure :> ISQ::pressure {
        unit = SI::pascal;
    }

    value def FlowRate :> ISQ::volumeFlowRate {
        unit = SI::cubicMetrePerSecond;
    }

    value def Volume :> ISQ::volume {
        unit = SI::cubicMetre;
    }

    value def Length :> ISQ::length {
        unit = SI::metre;
    }

    value def Diameter :> ISQ::length {
        unit = SI::metre;
    }

    value def Power :> ISQ::power {
        unit = SI::watt;
    }

    value def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    value def Density :> ISQ::massDensity {
        unit = SI::kilogramPerCubicMetre;
    }

    value def Fraction {
        :> ScalarValues::Real;
        range = "0..1";
    }

    value def RotationalSpeed {
        :> ScalarValues::Real;
        unit = "1/min";
    }

    item def Water {
        attribute temperature : Temperature;
        attribute density : Density = 997.0 [SI::kilogramPerCubicMetre];
    }

    item def CompressedAir {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute oilFree : Boolean;
    }

    item def AirWaterMixture {
        attribute voidFraction : Fraction;
        attribute mixtureDensity : Density;
        attribute flowRate : FlowRate;
    }

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute frequency : Real;
    }

    item def ControlSignal {
        attribute enabled : Boolean;
        attribute requestedFlowRate : FlowRate;
        attribute compressorSpeedCommand : Fraction;
    }

    item def MeasurementSignal {
        attribute valid : Boolean;
        attribute measuredValue : Real;
        attribute timeStamp_s : Real;
    }

    port def FluidInletPort {
        in item fluid : Water;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def FluidOutletPort {
        out item fluid : Water;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def AirSupplyPort {
        in item air : CompressedAir;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def MixturePort {
        item mixture : AirWaterMixture;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def PowerPort {
        in item power : ElectricalPower;
        attribute availablePower : Power;
    }

    port def ControlPort {
        in item command : ControlSignal;
    }

    port def SensorPort {
        out item measurement : MeasurementSignal;
    }

    part def IntakeScreen {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute meshOpening : Length = 0.003 [SI::metre];
        attribute screenArea : Real = 0.08;
        attribute maximumDebrisSize : Length = 0.0025 [SI::metre];

        requirement preventsClogging {
            doc /* Intake screen shall reject debris larger than the injector orifice clearance. */
            require constraint { maximumDebrisSize <= meshOpening; }
        }
    }

    part def AirCompressor {
        port electrical : PowerPort;
        port control : ControlPort;
        port airOut : AirSupplyPort;

        attribute ratedPower : Power = 750.0 [SI::watt];
        attribute maximumDischargePressure : Pressure = 450000.0 [SI::pascal];
        attribute nominalAirFlow : FlowRate = 0.0018 [SI::cubicMetrePerSecond];
        attribute speed : RotationalSpeed;
        attribute enabled : Boolean;

        state def CompressorStateMachine {
            state off;
            state starting;
            state running;
            state fault;

            transition off_to_starting
                first off
                then starting
                accept ControlSignal
                if command.enabled;

            transition starting_to_running
                first starting
                then running
                if electrical.availablePower >= ratedPower;

            transition running_to_off
                first running
                then off
                accept ControlSignal
                if not command.enabled;

            transition any_to_fault
                first running
                then fault
                if airOut.pressure > maximumDischargePressure;
        }

        perform compressorBehavior : CompressorStateMachine;
    }

    part def AirRegulator {
        port airIn : AirSupplyPort;
        port airOut : AirSupplyPort;
        port control : ControlPort;

        attribute setPressure : Pressure = 240000.0 [SI::pascal];
        attribute pressureTolerance : Pressure = 15000.0 [SI::pascal];
        attribute maximumOutletPressure : Pressure = 300000.0 [SI::pascal];

        requirement regulatedPressure {
            doc /* Regulator outlet pressure shall remain below the structural pressure limit of the injection manifold. */
            require constraint { airOut.pressure <= maximumOutletPressure; }
        }
    }

    part def CheckValve {
        port upstream : AirSupplyPort;
        port downstream : AirSupplyPort;

        attribute crackingPressure : Pressure = 3000.0 [SI::pascal];
        attribute reverseLeakageFlow : FlowRate = 0.0 [SI::cubicMetrePerSecond];

        requirement preventsBackflow {
            doc /* Check valve shall prevent water or mixture backflow into the compressor line. */
            require constraint { reverseLeakageFlow <= 0.000001 [SI::cubicMetrePerSecond]; }
        }
    }

    part def AirInjector {
        port airIn : AirSupplyPort;
        port waterIn : FluidInletPort;
        port mixtureOut : MixturePort;

        attribute orificeDiameter : Diameter = 0.0015 [SI::metre];
        attribute injectorDepth : Length = 1.8 [SI::metre];
        attribute minimumAirPressure : Pressure = 210000.0 [SI::pascal];
        attribute designVoidFraction : Fraction = 0.35;

        action mixAirAndWater {
            in item suppliedAir : CompressedAir;
            in item inletWater : Water;
            out item generatedMixture : AirWaterMixture;

            first start;
            then validateAirPressure;
            then entrainWater;
            then dischargeMixture;
            then done;

            assert constraint { airIn.pressure >= minimumAirPressure; }
            assert constraint { mixtureOut.mixture.voidFraction >= 0.20 and mixtureOut.mixture.voidFraction <= 0.55; }
        }
    }

    part def RiserTube {
        port mixtureIn : MixturePort;
        port mixtureOut : MixturePort;

        attribute innerDiameter : Diameter = 0.038 [SI::metre];
        attribute riserLength : Length = 3.2 [SI::metre];
        attribute submergenceRatio : Fraction = 0.56;
        attribute frictionLoss : Pressure = 18000.0 [SI::pascal];

        requirement adequateSubmergence {
            doc /* Riser tube shall maintain sufficient submergence for stable airlift pumping. */
            require constraint { submergenceRatio >= 0.50; }
        }
    }

    part def GasLiquidSeparator {
        port mixtureIn : MixturePort;
        port liquidOut : FluidOutletPort;
        port ventAirOut : AirSupplyPort;

        attribute separatorVolume : Volume = 0.012 [SI::cubicMetre];
        attribute airRemovalEfficiency : Fraction = 0.92;
        attribute retainedGasFractionLimit : Fraction = 0.08;

        requirement separatesAir {
            doc /* Separator shall remove enough entrained air to deliver usable liquid flow. */
            require constraint { airRemovalEfficiency >= 0.90; }
        }
    }

    part def DischargeManifold {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute manifoldDiameter : Diameter = 0.032 [SI::metre];
        attribute maximumWorkingPressure : Pressure = 350000.0 [SI::pascal];
        attribute nominalDischargeFlow : FlowRate = 0.0030 [SI::cubicMetrePerSecond];

        requirement pressureRated {
            doc /* Discharge manifold shall withstand maximum pump outlet pressure. */
            require constraint { outlet.pressure <= maximumWorkingPressure; }
        }
    }

    part def FlowSensor {
        port fluidIn : FluidInletPort;
        port fluidOut : FluidOutletPort;
        port measurement : SensorPort;

        attribute rangeMaximum : FlowRate = 0.0060 [SI::cubicMetrePerSecond];
        attribute accuracy : Fraction = 0.025;

        requirement measurementAccuracy {
            doc /* Flow sensor shall measure liquid discharge flow within specified accuracy. */
            require constraint { accuracy <= 0.03; }
        }
    }

    part def PressureSensor {
        port sensedFluid : FluidInletPort;
        port measurement : SensorPort;

        attribute rangeMaximum : Pressure = 500000.0 [SI::pascal];
        attribute accuracy : Fraction = 0.015;

        requirement pressureMeasurementAccuracy {
            doc /* Pressure sensor shall support pressure protection and control. */
            require constraint { accuracy <= 0.02; }
        }
    }

    part def Controller {
        port commandIn : ControlPort;
        port compressorCommand : ControlPort;
        port flowFeedback : SensorPort;
        port pressureFeedback : SensorPort;

        attribute targetFlowRate : FlowRate = 0.0025 [SI::cubicMetrePerSecond];
        attribute minimumFlowRate : FlowRate = 0.0015 [SI::cubicMetrePerSecond];
        attribute highPressureTrip : Pressure = 330000.0 [SI::pascal];
        attribute enabled : Boolean;

        action regulateFlow {
            in item operatorCommand : ControlSignal;
            in item flowMeasurement : MeasurementSignal;
            in item pressureMeasurement : MeasurementSignal;
            out item compressorSignal : ControlSignal;

            first idle;
            then evaluateCommand;
            then compareFlow;
            then adjustAirRate;
            then checkPressureTrip;
            then publishCommand;
            then done;

            assert constraint {
                compressorSignal.requestedFlowRate >= minimumFlowRate and
                compressorSignal.requestedFlowRate <= targetFlowRate;
            }
        }

        state def ControlStateMachine {
            state disabled;
            state priming;
            state pumping;
            state lowFlowRecovery;
            state shutdown;
            state fault;

            transition disabled_to_priming
                first disabled
                then priming
                accept ControlSignal
                if command.enabled;

            transition priming_to_pumping
                first priming
                then pumping
                if flowFeedback.measurement.valid;

            transition pumping_to_lowFlowRecovery
                first pumping
                then lowFlowRecovery
                if flowFeedback.measurement.measuredValue < 0.0015;

            transition lowFlowRecovery_to_pumping
                first lowFlowRecovery
                then pumping
                if flowFeedback.measurement.measuredValue >= 0.0015;

            transition pumping_to_shutdown
                first pumping
                then shutdown
                accept ControlSignal
                if not command.enabled;

            transition any_to_fault
                first pumping
                then fault
                if pressureFeedback.measurement.measuredValue > 330000.0;
        }

        perform controlBehavior : ControlStateMachine;
    }

    part def AirliftPumpSubsystem {
        port rawWaterIn : FluidInletPort;
        port pumpedWaterOut : FluidOutletPort;
        port electricalPowerIn : PowerPort;
        port operatorCommand : ControlPort;
        port ventedAirOut : AirSupplyPort;

        part intake : IntakeScreen;
        part compressor : AirCompressor;
        part regulator : AirRegulator;
        part checkValve : CheckValve;
        part injector : AirInjector;
        part riser : RiserTube;
        part separator : GasLiquidSeparator;
        part discharge : DischargeManifold;
        part flowSensor : FlowSensor;
        part pressureSensor : PressureSensor;
        part controller : Controller;

        attribute staticLift : Length = 1.4 [SI::metre];
        attribute totalRiserHeight : Length = 3.2 [SI::metre];
        attribute designLiquidFlowRate : FlowRate = 0.0025 [SI::cubicMetrePerSecond];
        attribute minimumLiquidFlowRate : FlowRate = 0.0015 [SI::cubicMetrePerSecond];
        attribute maximumAirPressure : Pressure = 300000.0 [SI::pascal];
        attribute maximumElectricalPower : Power = 900.0 [SI::watt];

        connect rawWaterIn to intake.inlet;
        connect intake.outlet to injector.waterIn;

        connect electricalPowerIn to compressor.electrical;
        connect operatorCommand to controller.commandIn;
        connect controller.compressorCommand to compressor.control;
        connect controller.compressorCommand to regulator.control;

        connect compressor.airOut to regulator.airIn;
        connect regulator.airOut to checkValve.upstream;
        connect checkValve.downstream to injector.airIn;

        connect injector.mixtureOut to riser.mixtureIn;
        connect riser.mixtureOut to separator.mixtureIn;
        connect separator.liquidOut to discharge.inlet;
        connect discharge.outlet to flowSensor.fluidIn;
        connect flowSensor.fluidOut to pumpedWaterOut;
        connect separator.ventAirOut to ventedAirOut;

        connect discharge.inlet to pressureSensor.sensedFluid;
        connect flowSensor.measurement to controller.flowFeedback;
        connect pressureSensor.measurement to controller.pressureFeedback;

        action operateAirliftPump {
            in item command : ControlSignal;
            out item dischargedWater : Water;

            first receiveCommand;
            then energizeCompressor;
            then regulateCompressedAir;
            then injectAirAtRiserBase;
            then reduceMixtureDensity;
            then liftMixtureThroughRiser;
            then separateGasFromLiquid;
            then dischargeLiquid;
            then monitorFlowAndPressure;
            then done;

            assert constraint { designLiquidFlowRate >= minimumLiquidFlowRate; }
            assert constraint { maximumElectricalPower >= compressor.ratedPower; }
            assert constraint { maximumAirPressure >= injector.minimumAirPressure; }
        }

        requirement pumpFluidByAirlift {
            doc /* The subsystem shall move water from the inlet to the discharge using air injection into a submerged riser. */
            subject subsystem : AirliftPumpSubsystem;
            require constraint { designLiquidFlowRate >= 0.0025 [SI::cubicMetrePerSecond]; }
        }

        requirement noMechanicalImpeller {
            doc /* The subsystem shall produce pumping action without a submerged mechanical impeller. */
            require constraint { true; }
        }

        requirement minimumLiftCapability {
            doc /* The subsystem shall lift liquid across the specified static lift. */
            require constraint { staticLift >= 1.4 [SI::metre]; }
        }

        requirement pressureProtection {
            doc /* The subsystem shall shut down or fault before discharge pressure exceeds the manifold rating. */
            require constraint { maximumAirPressure <= discharge.maximumWorkingPressure; }
        }

        requirement stableAirliftOperation {
            doc /* The subsystem shall maintain riser submergence and air void fraction needed for stable airlift operation. */
            require constraint {
                riser.submergenceRatio >= 0.50 and
                injector.designVoidFraction >= 0.20 and
                injector.designVoidFraction <= 0.55;
            }
        }

        requirement dischargeMeasurement {
            doc /* The subsystem shall measure delivered liquid flow for closed-loop air regulation. */
            require constraint { flowSensor.rangeMaximum >= designLiquidFlowRate; }
        }
    }

    part airliftPumpSystem : AirliftPumpSubsystem {
        attribute staticLift = 1.4 [SI::metre];
        attribute totalRiserHeight = 3.2 [SI::metre];
        attribute designLiquidFlowRate = 0.0025 [SI::cubicMetrePerSecond];
        attribute minimumLiquidFlowRate = 0.0015 [SI::cubicMetrePerSecond];
        attribute maximumAirPressure = 300000.0 [SI::pascal];
        attribute maximumElectricalPower = 900.0 [SI::watt];
    }

}