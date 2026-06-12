package RectifiedSineWaveSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Voltage :> Real {
        unit = V;
    }

    attribute def Current :> Real {
        unit = A;
    }

    attribute def Frequency :> Real {
        unit = Hz;
    }

    attribute def Time :> Real {
        unit = s;
    }

    attribute def Resistance :> Real {
        unit = Ohm;
    }

    attribute def Capacitance :> Real {
        unit = F;
    }

    attribute def RippleVoltage :> Real {
        unit = V;
    }

    attribute def Power :> Real {
        unit = W;
    }

    item def AlternatingWaveform {
        attribute instantaneousVoltage : Voltage;
        attribute rmsVoltage : Voltage;
        attribute frequency : Frequency;
        attribute phaseAngle : Real;
    }

    item def RectifiedWaveform {
        attribute instantaneousVoltage : Voltage;
        attribute averageVoltage : Voltage;
        attribute peakVoltage : Voltage;
        attribute rippleVoltage : RippleVoltage;
        attribute rippleFrequency : Frequency;
        attribute polarityPositive : Boolean;
    }

    item def RegulatedDcOutput {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute rippleVoltage : RippleVoltage;
        attribute deliveredPower : Power;
    }

    item def HeatFlow {
        attribute dissipatedPower : Power;
    }

    port def AcElectricalPort {
        in item acWave : AlternatingWaveform;
    }

    port def RectifiedElectricalPort {
        out item rectifiedWave : RectifiedWaveform;
    }

    port def DcElectricalPort {
        inout item dcPower : RegulatedDcOutput;
    }

    port def ThermalPort {
        out item heat : HeatFlow;
    }

    part def SineWaveSource {
        attribute nominalRmsVoltage : Voltage = 120.0 [V];
        attribute nominalFrequency : Frequency = 60.0 [Hz];
        attribute sourceResistance : Resistance = 0.2 [Ohm];

        port acOut : AcElectricalPort;

        action generateSineWave {
            out item generatedWave : AlternatingWaveform;
        }
    }

    part def FullWaveBridgeRectifier {
        attribute diodeForwardVoltage : Voltage = 0.7 [V];
        attribute maxForwardCurrent : Current = 5.0 [A];
        attribute conductionDiodeCount : Integer = 2;

        port acIn : AcElectricalPort;
        port rectifiedOut : RectifiedElectricalPort;
        port thermalOut : ThermalPort;

        action rectifyInput {
            in item inputWave : AlternatingWaveform;
            out item outputWave : RectifiedWaveform;
        }

        state rectifierOperatingState {
            entry; then idle;

            state idle;
            state positiveHalfCycleConducting;
            state negativeHalfCycleConducting;
            state overCurrentFault;

            transition idle_to_positive
                first idle
                accept when acIn.acWave.instantaneousVoltage > 0.0 [V]
                then positiveHalfCycleConducting;

            transition idle_to_negative
                first idle
                accept when acIn.acWave.instantaneousVoltage < 0.0 [V]
                then negativeHalfCycleConducting;

            transition positive_to_negative
                first positiveHalfCycleConducting
                accept when acIn.acWave.instantaneousVoltage < 0.0 [V]
                then negativeHalfCycleConducting;

            transition negative_to_positive
                first negativeHalfCycleConducting
                accept when acIn.acWave.instantaneousVoltage > 0.0 [V]
                then positiveHalfCycleConducting;

            transition any_to_fault
                first positiveHalfCycleConducting
                accept when rectifiedOut.rectifiedWave.instantaneousVoltage / Load.equivalentResistance > maxForwardCurrent
                then overCurrentFault;
        }
    }

    part def SmoothingFilter {
        attribute filterCapacitance : Capacitance = 2200.0e-6 [F];
        attribute equivalentSeriesResistance : Resistance = 0.08 [Ohm];
        attribute targetRippleVoltage : RippleVoltage = 1.0 [V];

        port rectifiedIn : RectifiedElectricalPort;
        port dcOut : DcElectricalPort;
        port thermalOut : ThermalPort;

        action storeAndReleaseEnergy {
            in item pulsedWave : RectifiedWaveform;
            out item smoothedOutput : RegulatedDcOutput;
        }

        state capacitorState {
            entry; then charging;

            state charging;
            state discharging;
            state excessiveRipple;

            transition charging_to_discharging
                first charging
                accept when rectifiedIn.rectifiedWave.instantaneousVoltage < dcOut.dcPower.voltage
                then discharging;

            transition discharging_to_charging
                first discharging
                accept when rectifiedIn.rectifiedWave.instantaneousVoltage > dcOut.dcPower.voltage
                then charging;

            transition ripple_fault
                first discharging
                accept when dcOut.dcPower.rippleVoltage > targetRippleVoltage
                then excessiveRipple;
        }
    }

    part def Load {
        attribute equivalentResistance : Resistance = 24.0 [Ohm];
        attribute minimumOperatingVoltage : Voltage = 10.0 [V];
        attribute maximumOperatingVoltage : Voltage = 15.0 [V];

        port dcIn : DcElectricalPort;

        action consumeDcPower {
            in item suppliedPower : RegulatedDcOutput;
        }

        state loadState {
            entry; then unpowered;

            state unpowered;
            state operating;
            state undervoltage;
            state overvoltage;

            transition power_available
                first unpowered
                accept when dcIn.dcPower.voltage >= minimumOperatingVoltage
                then operating;

            transition voltage_low
                first operating
                accept when dcIn.dcPower.voltage < minimumOperatingVoltage
                then undervoltage;

            transition voltage_high
                first operating
                accept when dcIn.dcPower.voltage > maximumOperatingVoltage
                then overvoltage;

            transition recovered_from_low
                first undervoltage
                accept when dcIn.dcPower.voltage >= minimumOperatingVoltage
                then operating;

            transition recovered_from_high
                first overvoltage
                accept when dcIn.dcPower.voltage <= maximumOperatingVoltage
                then operating;
        }
    }

    part def RectifiedSineWavePowerSystem {
        attribute inputRmsVoltage : Voltage = 120.0 [V];
        attribute inputFrequency : Frequency = 60.0 [Hz];
        attribute nominalOutputVoltage : Voltage = 12.0 [V];
        attribute nominalOutputCurrent : Current = 0.5 [A];
        attribute maximumAllowedRipple : RippleVoltage = 1.0 [V];
        attribute conversionEfficiency : Real = 0.82;

        part source : SineWaveSource;
        part bridgeRectifier : FullWaveBridgeRectifier;
        part smoothingFilter : SmoothingFilter;
        part load : Load;

        port acInput : AcElectricalPort;
        port dcOutput : DcElectricalPort;
        port heatOutput : ThermalPort;

        connect acInput to source.acOut;
        connect source.acOut to bridgeRectifier.acIn;
        connect bridgeRectifier.rectifiedOut to smoothingFilter.rectifiedIn;
        connect smoothingFilter.dcOut to load.dcIn;
        connect smoothingFilter.dcOut to dcOutput;
        connect bridgeRectifier.thermalOut to heatOutput;
        connect smoothingFilter.thermalOut to heatOutput;

        action convertRectifiedSineWaveToDc {
            in item input : AlternatingWaveform;
            out item output : RegulatedDcOutput;

            first source.generateSineWave;
            then bridgeRectifier.rectifyInput;
            then smoothingFilter.storeAndReleaseEnergy;
            then load.consumeDcPower;
        }

        state systemState {
            entry; then standby;

            state standby;
            state rectifying;
            state filtering;
            state supplyingLoad;
            state fault;

            transition start_conversion
                first standby
                accept when acInput.acWave.rmsVoltage > 0.0 [V]
                then rectifying;

            transition rectified_available
                first rectifying
                accept when bridgeRectifier.rectifiedOut.rectifiedWave.polarityPositive == true
                then filtering;

            transition dc_ready
                first filtering
                accept when smoothingFilter.dcOut.dcPower.voltage >= load.minimumOperatingVoltage
                then supplyingLoad;

            transition ripple_fault
                first supplyingLoad
                accept when smoothingFilter.dcOut.dcPower.rippleVoltage > maximumAllowedRipple
                then fault;

            transition output_fault
                first supplyingLoad
                accept when smoothingFilter.dcOut.dcPower.voltage > load.maximumOperatingVoltage
                then fault;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : RectifiedSineWavePowerSystem;

        doc /* The system shall transform an alternating sinusoidal input into a unidirectional rectified waveform and smooth that waveform into usable direct-current power for a load. */

        require constraint {
            system.dcOutput.dcPower.voltage >= system.load.minimumOperatingVoltage and
            system.dcOutput.dcPower.voltage <= system.load.maximumOperatingVoltage
        }
    }

    requirement def FullWaveRectificationRequirement {
        subject rectifier : FullWaveBridgeRectifier;

        doc /* The rectifier shall convert both positive and negative half cycles of the sine wave into positive-polarity output pulses. */

        require constraint {
            rectifier.rectifiedOut.rectifiedWave.polarityPositive == true and
            rectifier.rectifiedOut.rectifiedWave.rippleFrequency == 2.0 * rectifier.acIn.acWave.frequency
        }
    }

    requirement def RippleLimitRequirement {
        subject filter : SmoothingFilter;

        doc /* The smoothing filter shall reduce the rectified waveform ripple to a level acceptable for the connected load. */

        require constraint {
            filter.dcOut.dcPower.rippleVoltage <= filter.targetRippleVoltage
        }
    }

    requirement def LoadPowerRequirement {
        subject system : RectifiedSineWavePowerSystem;

        doc /* The system shall deliver the nominal output current to the load while maintaining the regulated DC voltage range. */

        require constraint {
            system.dcOutput.dcPower.current >= system.nominalOutputCurrent and
            system.dcOutput.dcPower.voltage >= 10.0 [V] and
            system.dcOutput.dcPower.voltage <= 15.0 [V]
        }
    }

    requirement def ThermalDissipationRequirement {
        subject system : RectifiedSineWavePowerSystem;

        doc /* Rectification and filtering losses shall be represented as heat generated by the bridge rectifier and smoothing filter. */

        require constraint {
            system.heatOutput.heat.dissipatedPower ==
            (system.inputRmsVoltage * system.nominalOutputCurrent) * (1.0 - system.conversionEfficiency)
        }
    }

    constraint def RectifiedSineWaveRelation {
        in vin : Voltage;
        in diodeDrop : Voltage;
        out vrect : Voltage;

        vrect == abs(vin) - 2.0 * diodeDrop;
    }

    constraint def CapacitiveRippleEstimate {
        in loadCurrent : Current;
        in rippleFrequency : Frequency;
        in capacitance : Capacitance;
        out ripple : RippleVoltage;

        ripple == loadCurrent / (rippleFrequency * capacitance);
    }

    part rectifiedSineWaveSupply : RectifiedSineWavePowerSystem;

    satisfy PrimaryFunctionRequirement by rectifiedSineWaveSupply;
    satisfy FullWaveRectificationRequirement by rectifiedSineWaveSupply.bridgeRectifier;
    satisfy RippleLimitRequirement by rectifiedSineWaveSupply.smoothingFilter;
    satisfy LoadPowerRequirement by rectifiedSineWaveSupply;
    satisfy ThermalDissipationRequirement by rectifiedSineWaveSupply;
}