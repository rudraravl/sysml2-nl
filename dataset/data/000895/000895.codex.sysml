package HydraulicCompressorSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> Real {
        unit = "Pa";
    }

    attribute def FlowRate :> Real {
        unit = "m^3/s";
    }

    attribute def Volume :> Real {
        unit = "m^3";
    }

    attribute def Temperature :> Real {
        unit = "K";
    }

    attribute def RotationalSpeed :> Real {
        unit = "rad/s";
    }

    attribute def Power :> Real {
        unit = "W";
    }

    attribute def Efficiency :> Real {
        unit = "1";
    }

    attribute def Force :> Real {
        unit = "N";
    }

    attribute def TimeDuration :> Real {
        unit = "s";
    }

    item def HydraulicFluid {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        attribute temperature : Temperature;
        attribute contaminationLevel : Real;
    }

    item def AmbientAir {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute humidityRatio : Real;
    }

    item def CompressedAir {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        attribute temperature : Temperature;
        attribute oilCarryover : Real;
    }

    item def MechanicalTorque {
        attribute torque : Real {
            unit = "N*m";
        }
        attribute speed : RotationalSpeed;
    }

    item def ElectricalSignal {
        attribute voltage : Real {
            unit = "V";
        }
        attribute current : Real {
            unit = "A";
        }
        attribute valid : Boolean;
    }

    port def HydraulicInletPort {
        in item fluidIn : HydraulicFluid;
    }

    port def HydraulicOutletPort {
        out item fluidOut : HydraulicFluid;
    }

    port def AirInletPort {
        in item airIn : AmbientAir;
    }

    port def AirOutletPort {
        out item airOut : CompressedAir;
    }

    port def ShaftPort {
        inout item torqueTransfer : MechanicalTorque;
    }

    port def SignalInputPort {
        in item command : ElectricalSignal;
    }

    port def SignalOutputPort {
        out item status : ElectricalSignal;
    }

    part def HydraulicPump {
        port hydraulicSupply : HydraulicInletPort;
        port hydraulicDischarge : HydraulicOutletPort;
        port shaftDrive : ShaftPort;

        attribute displacement : Volume = 0.000028;
        attribute nominalSpeed : RotationalSpeed = 157.1;
        attribute nominalFlow : FlowRate = 0.0042;
        attribute nominalPressureRise : Pressure = 21000000.0;
        attribute volumetricEfficiency : Efficiency = 0.92;

        perform action PressurizeFluid {
            in item inletFluid : HydraulicFluid;
            out item outletFluid : HydraulicFluid;
            in item driveTorque : MechanicalTorque;

            assign outletFluid.pressure := inletFluid.pressure + nominalPressureRise;
            assign outletFluid.flowRate := nominalFlow * volumetricEfficiency;
            assign outletFluid.temperature := inletFluid.temperature + 8.0;
        }
    }

    part def HydraulicMotor {
        port hydraulicInput : HydraulicInletPort;
        port hydraulicReturn : HydraulicOutletPort;
        port outputShaft : ShaftPort;

        attribute displacement : Volume = 0.000032;
        attribute mechanicalEfficiency : Efficiency = 0.88;
        attribute ratedOutputPower : Power = 35000.0;
        attribute minimumOperatingPressure : Pressure = 12000000.0;

        perform action ConvertHydraulicPowerToTorque {
            in item pressurizedFluid : HydraulicFluid;
            out item returnFluid : HydraulicFluid;
            out item shaftTorque : MechanicalTorque;

            assign returnFluid.pressure := 900000.0;
            assign returnFluid.flowRate := pressurizedFluid.flowRate;
            assign returnFluid.temperature := pressurizedFluid.temperature + 6.0;
            assign shaftTorque.speed := 314.2;
            assign shaftTorque.torque := ratedOutputPower / shaftTorque.speed * mechanicalEfficiency;
        }
    }

    part def CompressionElement {
        port airIntake : AirInletPort;
        port airDischarge : AirOutletPort;
        port driveShaft : ShaftPort;

        attribute compressionRatio : Real = 8.0;
        attribute nominalOutletPressure : Pressure = 800000.0;
        attribute nominalAirFlow : FlowRate = 0.62;
        attribute maximumOutletTemperature : Temperature = 450.0;
        attribute isentropicEfficiency : Efficiency = 0.78;

        perform action CompressAir {
            in item inletAir : AmbientAir;
            in item shaftPower : MechanicalTorque;
            out item outletAir : CompressedAir;

            assign outletAir.pressure := inletAir.pressure * compressionRatio;
            assign outletAir.flowRate := nominalAirFlow;
            assign outletAir.temperature := inletAir.temperature + 105.0;
            assign outletAir.oilCarryover := 0.000003;
        }
    }

    part def HeatExchanger {
        port airInput : AirInletPort;
        port airOutput : AirOutletPort;

        attribute coolingCapacity : Power = 12000.0;
        attribute targetOutletTemperature : Temperature = 315.0;
        attribute maximumPressureDrop : Pressure = 18000.0;

        perform action CoolCompressedAir {
            in item hotAir : CompressedAir;
            out item cooledAir : CompressedAir;

            assign cooledAir.pressure := hotAir.pressure - maximumPressureDrop;
            assign cooledAir.flowRate := hotAir.flowRate;
            assign cooledAir.temperature := targetOutletTemperature;
            assign cooledAir.oilCarryover := hotAir.oilCarryover;
        }
    }

    part def OilSeparator {
        port mixedAirInput : AirInletPort;
        port cleanAirOutput : AirOutletPort;

        attribute separationEfficiency : Efficiency = 0.995;
        attribute maximumOilCarryover : Real = 0.0000005;
        attribute pressureDrop : Pressure = 25000.0;

        perform action RemoveOilMist {
            in item mixedAir : CompressedAir;
            out item cleanAir : CompressedAir;

            assign cleanAir.pressure := mixedAir.pressure - pressureDrop;
            assign cleanAir.flowRate := mixedAir.flowRate;
            assign cleanAir.temperature := mixedAir.temperature;
            assign cleanAir.oilCarryover := mixedAir.oilCarryover * (1.0 - separationEfficiency);
        }
    }

    part def Reservoir {
        port hydraulicReturn : HydraulicInletPort;
        port hydraulicSupply : HydraulicOutletPort;

        attribute capacity : Volume = 0.085;
        attribute nominalFluidTemperature : Temperature = 320.0;
        attribute minimumUsableVolume : Volume = 0.035;
        attribute currentVolume : Volume = 0.075;

        perform action ConditionHydraulicFluid {
            in item returnedFluid : HydraulicFluid;
            out item conditionedFluid : HydraulicFluid;

            assign conditionedFluid.pressure := 300000.0;
            assign conditionedFluid.flowRate := returnedFluid.flowRate;
            assign conditionedFluid.temperature := nominalFluidTemperature;
            assign conditionedFluid.contaminationLevel := returnedFluid.contaminationLevel * 0.7;
        }
    }

    part def Filter {
        port dirtyFluidInput : HydraulicInletPort;
        port cleanFluidOutput : HydraulicOutletPort;

        attribute betaRatio : Real = 200.0;
        attribute maximumPressureDrop : Pressure = 350000.0;
        attribute bypassCrackingPressure : Pressure = 500000.0;

        perform action FilterFluid {
            in item dirtyFluid : HydraulicFluid;
            out item cleanFluid : HydraulicFluid;

            assign cleanFluid.pressure := dirtyFluid.pressure - maximumPressureDrop;
            assign cleanFluid.flowRate := dirtyFluid.flowRate;
            assign cleanFluid.temperature := dirtyFluid.temperature;
            assign cleanFluid.contaminationLevel := dirtyFluid.contaminationLevel / betaRatio;
        }
    }

    part def ControlUnit {
        port operatorCommand : SignalInputPort;
        port pumpCommand : SignalOutputPort;
        port statusOutput : SignalOutputPort;

        attribute commandedRun : Boolean = false;
        attribute faultActive : Boolean = false;
        attribute targetDischargePressure : Pressure = 750000.0;
        attribute startupDelay : TimeDuration = 2.0;

        perform action EvaluateCommand {
            in item commandSignal : ElectricalSignal;
            out item pumpSignal : ElectricalSignal;
            out item statusSignal : ElectricalSignal;

            assign commandedRun := commandSignal.valid and commandSignal.voltage > 18.0;
            assign pumpSignal.voltage := if commandedRun then 24.0 else 0.0;
            assign pumpSignal.current := if commandedRun then 1.2 else 0.0;
            assign pumpSignal.valid := not faultActive;
            assign statusSignal.voltage := if faultActive then 0.0 else 24.0;
            assign statusSignal.current := 0.05;
            assign statusSignal.valid := true;
        }

        state def ControllerOperatingState {
            state Off;
            state Standby;
            state Starting;
            state Running;
            state Faulted;

            entry action Initialize {
                assign commandedRun := false;
                assign faultActive := false;
            }

            transition first Off;
            transition Off_to_Standby
                first Off
                then Standby;

            transition Standby_to_Starting
                first Standby
                accept when commandedRun and not faultActive
                then Starting;

            transition Starting_to_Running
                first Starting
                accept after startupDelay
                then Running;

            transition Running_to_Standby
                first Running
                accept when not commandedRun
                then Standby;

            transition Any_to_Faulted
                first Standby
                accept when faultActive
                then Faulted;

            transition Running_to_Faulted
                first Running
                accept when faultActive
                then Faulted;

            transition Faulted_to_Standby
                first Faulted
                accept when not faultActive and not commandedRun
                then Standby;
        }
    }

    part def PressureSensor {
        port sensedAir : AirInletPort;
        port pressureSignal : SignalOutputPort;

        attribute measurementRange : Pressure = 1200000.0;
        attribute accuracy : Pressure = 5000.0;

        perform action MeasurePressure {
            in item measuredAir : CompressedAir;
            out item signal : ElectricalSignal;

            assign signal.voltage := measuredAir.pressure / measurementRange * 10.0;
            assign signal.current := 0.02;
            assign signal.valid := measuredAir.pressure <= measurementRange;
        }
    }

    part def ReliefValve {
        port inlet : HydraulicInletPort;
        port outlet : HydraulicOutletPort;

        attribute crackingPressure : Pressure = 24000000.0;
        attribute fullFlowPressure : Pressure = 26000000.0;
        attribute reliefFlowCapacity : FlowRate = 0.005;

        perform action LimitHydraulicPressure {
            in item highPressureFluid : HydraulicFluid;
            out item relievedFluid : HydraulicFluid;

            assign relievedFluid.pressure := if highPressureFluid.pressure > crackingPressure then crackingPressure else highPressureFluid.pressure;
            assign relievedFluid.flowRate := highPressureFluid.flowRate;
            assign relievedFluid.temperature := highPressureFluid.temperature + 3.0;
            assign relievedFluid.contaminationLevel := highPressureFluid.contaminationLevel;
        }
    }

    part def HydraulicCompressor {
        port hydraulicFluidSupply : HydraulicInletPort;
        port hydraulicFluidReturn : HydraulicOutletPort;
        port ambientAirIntake : AirInletPort;
        port compressedAirDelivery : AirOutletPort;
        port commandInput : SignalInputPort;
        port healthStatus : SignalOutputPort;

        attribute ratedHydraulicPressure : Pressure = 21000000.0;
        attribute ratedAirDischargePressure : Pressure = 750000.0;
        attribute ratedAirFlow : FlowRate = 0.58;
        attribute maximumAirTemperature : Temperature = 350.0;
        attribute minimumOverallEfficiency : Efficiency = 0.62;
        attribute primaryFunctionStatement : String =
            "Convert hydraulic power into a controlled flow of compressed air for downstream pneumatic consumers.";

        part reservoir : Reservoir;
        part filter : Filter;
        part pump : HydraulicPump;
        part reliefValve : ReliefValve;
        part motor : HydraulicMotor;
        part compressionElement : CompressionElement;
        part aftercooler : HeatExchanger;
        part separator : OilSeparator;
        part controller : ControlUnit;
        part dischargePressureSensor : PressureSensor;

        connect hydraulicFluidSupply to reservoir.hydraulicReturn;
        connect reservoir.hydraulicSupply to filter.dirtyFluidInput;
        connect filter.cleanFluidOutput to pump.hydraulicSupply;
        connect pump.hydraulicDischarge to reliefValve.inlet;
        connect reliefValve.outlet to motor.hydraulicInput;
        connect motor.hydraulicReturn to hydraulicFluidReturn;
        connect motor.outputShaft to compressionElement.driveShaft;
        connect ambientAirIntake to compressionElement.airIntake;
        connect compressionElement.airDischarge to aftercooler.airInput;
        connect aftercooler.airOutput to separator.mixedAirInput;
        connect separator.cleanAirOutput to compressedAirDelivery;
        connect compressedAirDelivery to dischargePressureSensor.sensedAir;
        connect commandInput to controller.operatorCommand;
        connect controller.statusOutput to healthStatus;

        perform action PrimaryFunction {
            in item hydraulicPowerFluid : HydraulicFluid;
            in item ambientAir : AmbientAir;
            in item operatorCommandSignal : ElectricalSignal;
            out item deliveredAir : CompressedAir;
            out item returnedFluid : HydraulicFluid;
            out item systemStatus : ElectricalSignal;

            objective {
                doc "Use pressurized hydraulic fluid as the energy source to drive a compression element, draw in ambient air, raise the air pressure, cool and separate oil from the air stream, and deliver regulated compressed air at the outlet while returning hydraulic fluid to the supply reservoir.";
            }

            first controller.EvaluateCommand(
                commandSignal = operatorCommandSignal,
                pumpSignal = controller.pumpCommand.status,
                statusSignal = systemStatus
            );

            then reservoir.ConditionHydraulicFluid(
                returnedFluid = hydraulicPowerFluid,
                conditionedFluid = reservoir.hydraulicSupply.fluidOut
            );

            then filter.FilterFluid(
                dirtyFluid = reservoir.hydraulicSupply.fluidOut,
                cleanFluid = filter.cleanFluidOutput.fluidOut
            );

            then pump.PressurizeFluid(
                inletFluid = filter.cleanFluidOutput.fluidOut,
                outletFluid = pump.hydraulicDischarge.fluidOut,
                driveTorque = pump.shaftDrive.torqueTransfer
            );

            then reliefValve.LimitHydraulicPressure(
                highPressureFluid = pump.hydraulicDischarge.fluidOut,
                relievedFluid = reliefValve.outlet.fluidOut
            );

            then motor.ConvertHydraulicPowerToTorque(
                pressurizedFluid = reliefValve.outlet.fluidOut,
                returnFluid = returnedFluid,
                shaftTorque = motor.outputShaft.torqueTransfer
            );

            then compressionElement.CompressAir(
                inletAir = ambientAir,
                shaftPower = motor.outputShaft.torqueTransfer,
                outletAir = compressionElement.airDischarge.airOut
            );

            then aftercooler.CoolCompressedAir(
                hotAir = compressionElement.airDischarge.airOut,
                cooledAir = aftercooler.airOutput.airOut
            );

            then separator.RemoveOilMist(
                mixedAir = aftercooler.airOutput.airOut,
                cleanAir = deliveredAir
            );
        }

        state def HydraulicCompressorOperatingState {
            state ShutDown;
            state Ready;
            state HydraulicPressureBuild;
            state Compressing;
            state Unloading;
            state OverTemperatureTrip;
            state OverPressureTrip;

            transition initial_to_ShutDown
                first ShutDown;

            transition ShutDown_to_Ready
                first ShutDown
                accept when commandInput.command.valid
                then Ready;

            transition Ready_to_HydraulicPressureBuild
                first Ready
                accept when commandInput.command.voltage >= 18.0
                then HydraulicPressureBuild;

            transition HydraulicPressureBuild_to_Compressing
                first HydraulicPressureBuild
                accept when reliefValve.outlet.fluidOut.pressure >= motor.minimumOperatingPressure
                then Compressing;

            transition Compressing_to_Unloading
                first Compressing
                accept when compressedAirDelivery.airOut.pressure >= ratedAirDischargePressure
                then Unloading;

            transition Unloading_to_Compressing
                first Unloading
                accept when compressedAirDelivery.airOut.pressure < ratedAirDischargePressure * 0.85
                then Compressing;

            transition Compressing_to_OverTemperatureTrip
                first Compressing
                accept when compressedAirDelivery.airOut.temperature > maximumAirTemperature
                then OverTemperatureTrip;

            transition Compressing_to_OverPressureTrip
                first Compressing
                accept when compressedAirDelivery.airOut.pressure > ratedAirDischargePressure * 1.15
                then OverPressureTrip;

            transition Trip_to_ShutDown
                first OverTemperatureTrip
                accept when commandInput.command.voltage < 5.0
                then ShutDown;

            transition PressureTrip_to_ShutDown
                first OverPressureTrip
                accept when commandInput.command.voltage < 5.0
                then ShutDown;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject compressor : HydraulicCompressor;

        doc "The hydraulic compressor shall convert hydraulic input power into compressed air output for pneumatic consumers at a controlled discharge pressure and flow rate.";

        require constraint {
            compressor.compressedAirDelivery.airOut.pressure >= 700000.0 and
            compressor.compressedAirDelivery.airOut.pressure <= 800000.0 and
            compressor.compressedAirDelivery.airOut.flowRate >= 0.55
        }
    }

    requirement def HydraulicEnergyRequirement {
        subject compressor : HydraulicCompressor;

        doc "The hydraulic compressor shall operate from hydraulic fluid supplied at or below the rated hydraulic pressure without exceeding the relief valve limit.";

        require constraint {
            compressor.pump.hydraulicDischarge.fluidOut.pressure <= compressor.reliefValve.fullFlowPressure and
            compressor.ratedHydraulicPressure <= compressor.reliefValve.crackingPressure
        }
    }

    requirement def AirQualityRequirement {
        subject compressor : HydraulicCompressor;

        doc "The compressor shall deliver cooled compressed air with limited oil carryover.";

        require constraint {
            compressor.compressedAirDelivery.airOut.temperature <= compressor.maximumAirTemperature and
            compressor.compressedAirDelivery.airOut.oilCarryover <= compressor.separator.maximumOilCarryover
        }
    }

    requirement def ControlAndProtectionRequirement {
        subject compressor : HydraulicCompressor;

        doc "The compressor shall transition to a protective trip state when discharge pressure or temperature exceeds defined safe limits.";

        require constraint {
            compressor.compressedAirDelivery.airOut.pressure <= compressor.ratedAirDischargePressure * 1.15 and
            compressor.compressedAirDelivery.airOut.temperature <= compressor.maximumAirTemperature
        }
    }

    requirement def EfficiencyRequirement {
        subject compressor : HydraulicCompressor;

        doc "The compressor shall maintain a minimum overall energy conversion efficiency during rated operation.";

        require constraint {
            compressor.minimumOverallEfficiency >= 0.62 and
            compressor.motor.mechanicalEfficiency * compressor.compressionElement.isentropicEfficiency >= compressor.minimumOverallEfficiency
        }
    }

    satisfy PrimaryFunctionRequirement by HydraulicCompressor::PrimaryFunction;
    satisfy HydraulicEnergyRequirement by HydraulicCompressor::reliefValve;
    satisfy AirQualityRequirement by HydraulicCompressor::separator;
    satisfy AirQualityRequirement by HydraulicCompressor::aftercooler;
    satisfy ControlAndProtectionRequirement by HydraulicCompressor::HydraulicCompressorOperatingState;
    satisfy EfficiencyRequirement by HydraulicCompressor::motor;
    satisfy EfficiencyRequirement by HydraulicCompressor::compressionElement;

    part hydraulicCompressorSystem : HydraulicCompressor {
        attribute ratedHydraulicPressure = 21000000.0;
        attribute ratedAirDischargePressure = 750000.0;
        attribute ratedAirFlow = 0.58;
        attribute maximumAirTemperature = 350.0;
        attribute minimumOverallEfficiency = 0.62;
    }
}