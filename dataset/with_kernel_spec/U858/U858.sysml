package RVDT {
    doc
    /*
     * Rotary Variable Differential Transformer (RVDT) model.
     * A high-precision electromechanical sensor for contactless
     * measurement of angular position.
     */
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def ShaftAngle :> ISQ::PlaneAngleValue;
    attribute def ACVoltage :> ISQ::ElectricPotentialValue;
    attribute def ExcitationFreq :> ISQ::FrequencyValue;
    attribute def OpTemp :> ISQ::ThermodynamicTemperatureValue;
    attribute def LinearityErr :> ISQ::PlaneAngleValue;

    item def ExcitationSignal {
        attribute voltage: ACVoltage;
        attribute frequency: ExcitationFreq;
    }

    item def SecondaryVoltage {
        attribute amplitude: ACVoltage;
        attribute phase: Real;
    }

    item def DemodulatedSignal {
        attribute differential: ACVoltage;
        attribute phase: Real;
    }

    item def AngleMeasurement {
        attribute angle: ShaftAngle;
        attribute temperature: OpTemp;
        attribute compensated: Boolean;
    }

    attribute def CalibrationData {
        attribute zeroOffset: ShaftAngle;
        attribute scaleFactor: Real;
        attribute tempCoeff: Real;
    }

    attribute def PowerOn;
    attribute def PowerOff;
    attribute def StartMeasurement;
    attribute def StopMeasurement;

    port def ExcitationPort {
        in item excitation: ExcitationSignal;
    }

    port def SecondaryOutputPort {
        out item voltage: SecondaryVoltage;
    }

    port def SecondaryInputPort {
        in item voltage: SecondaryVoltage;
    }

    port def DemodOutputPort {
        out item demodulated: DemodulatedSignal;
    }

    port def DemodInputPort {
        in item demodulated: DemodulatedSignal;
    }

    port def AngleOutputPort {
        out item measurement: AngleMeasurement;
    }

    action def EnergizePrimary {
        in item excitation: ExcitationSignal;
        out item magneticFlux;
    }

    action def CoupleFlux {
        in item magneticFlux;
        in attribute shaftAngle: ShaftAngle;
        out item coupledFlux1;
        out item coupledFlux2;
    }

    action def InduceSecondaryVoltage {
        in item coupledFlux;
        out item secondaryVoltage: SecondaryVoltage;
    }

    action def DemodulateVoltages {
        in item secondaryVoltage1: SecondaryVoltage;
        in item secondaryVoltage2: SecondaryVoltage;
        in item reference: ExcitationSignal;
        out item demodulated: DemodulatedSignal;
    }

    action def CalculateAngleAction {
        in item demodulated: DemodulatedSignal;
        in attribute calibration: CalibrationData;
        in attribute temperature: OpTemp;
        out item measurement: AngleMeasurement;
    }

    action def ProcessSignal {
        in item excitation: ExcitationSignal;
        in attribute shaftAngle: ShaftAngle;
        in attribute temperature: OpTemp;
        in attribute calibration: CalibrationData;
        out item measurement: AngleMeasurement;

        action energize: EnergizePrimary;
        action couple: CoupleFlux;
        action induce1: InduceSecondaryVoltage;
        action induce2: InduceSecondaryVoltage;
        action demodulate: DemodulateVoltages;
        action calculate: CalculateAngleAction;

        flow energize.magneticFlux to couple.magneticFlux;
        flow couple.coupledFlux1 to induce1.coupledFlux;
        flow couple.coupledFlux2 to induce2.coupledFlux;
        flow induce1.secondaryVoltage to demodulate.secondaryVoltage1;
        flow induce2.secondaryVoltage to demodulate.secondaryVoltage2;
        flow demodulate.demodulated to calculate.demodulated;

        first start;
        then energize;
        then couple;
        then demodulate;
        then calculate;
        then done;
    }

    part def PrimaryCoil {
        attribute turns: Integer = 500;
        port excitationIn: ExcitationPort;
        out item magneticFlux;
    }

    part def Rotor {
        attribute material: String = "Ferromagnetic";
        attribute shaftAngle: ShaftAngle;
        attribute couplingCoeff: Real;
        in item magneticFlux;
        out item coupledFlux1;
        out item coupledFlux2;
    }

    part def SecondaryCoil {
        attribute turns: Integer = 1000;
        in item coupledFlux;
        port voltageOut: SecondaryOutputPort;
    }

    part def Demodulator {
        port input1: SecondaryInputPort;
        port input2: SecondaryInputPort;
        port referenceIn: ExcitationPort;
        port output: DemodOutputPort;
    }

    part def AngleCalculator {
        port demodIn: DemodInputPort;
        port angleOut: AngleOutputPort;
        attribute calibration: CalibrationData;
        attribute temperature: OpTemp;
    }

    part def RVDTAssembly {
        port excitationInput: ExcitationPort;
        port angleOutput: AngleOutputPort;
        attribute shaftAngle: ShaftAngle;
        attribute operatingTemp: OpTemp;
        attribute linearityError: LinearityErr;
        attribute calibration: CalibrationData;

        part primaryCoil: PrimaryCoil;
        part rotor: Rotor;
        part secondaryCoil1: SecondaryCoil;
        part secondaryCoil2: SecondaryCoil;
        part demodulator: Demodulator;
        part angleCalculator: AngleCalculator;

        bind rotor.shaftAngle = shaftAngle;
        bind angleCalculator.temperature = operatingTemp;
        bind angleCalculator.calibration = calibration;

        connect excitationInput to primaryCoil.excitationIn;
        connect excitationInput to demodulator.referenceIn;
        flow primaryCoil.magneticFlux to rotor.magneticFlux;
        flow rotor.coupledFlux1 to secondaryCoil1.coupledFlux;
        flow rotor.coupledFlux2 to secondaryCoil2.coupledFlux;
        connect secondaryCoil1.voltageOut to demodulator.input1;
        connect secondaryCoil2.voltageOut to demodulator.input2;
        connect demodulator.output to angleCalculator.demodIn;
        connect angleCalculator.angleOut to angleOutput;

        state RVDTStates {
            state Idle;
            state Energized;
            state Measuring;
            transition first Idle accept PowerOn then Energized;
            transition first Energized accept StartMeasurement then Measuring;
            transition first Measuring accept StopMeasurement then Energized;
            transition first Energized accept PowerOff then Idle;
            transition first Measuring accept PowerOff then Idle;
        }
    }

    requirement def MeasurementAccuracyRequirement {
        doc
        /*
         * The RVDT shall maintain linearity error within specified limits.
         */
        attribute maxLinearityError: LinearityErr = 0.5 [deg];
        subject rvdt: RVDTAssembly;
        constraint { rvdt.linearityError <= maxLinearityError }
    }

    requirement def OperatingRangeRequirement {
        doc
        /*
         * The RVDT shall operate over a full 360-degree range
         * and across a wide temperature spectrum.
         */
        attribute minAngle: ShaftAngle = 0 [deg];
        attribute maxAngle: ShaftAngle = 360 [deg];
        attribute minTemp: OpTemp = 218 [K];
        attribute maxTemp: OpTemp = 398 [K];
        subject rvdt: RVDTAssembly;
        constraint { rvdt.shaftAngle >= minAngle and rvdt.shaftAngle <= maxAngle }
    }

    requirement def ContactlessDesignRequirement {
        doc
        /*
         * The RVDT shall use a contactless design for long operational life
         * free from mechanical wear.
         */
        subject rvdt: RVDTAssembly;
        constraint { rvdt.rotor.material == "Ferromagnetic" }
    }

    requirement def ExcitationRequirement {
        doc
        /*
         * The RVDT shall accept AC excitation within specified frequency range.
         */
        attribute minFrequency: ExcitationFreq = 400 [Hz];
        attribute maxFrequency: ExcitationFreq = 20000 [Hz];
        subject rvdt: RVDTAssembly;
        constraint { rvdt.excitationInput.excitation.frequency >= minFrequency and rvdt.excitationInput.excitation.frequency <= maxFrequency }
    }

    requirement def TemperatureCompensationRequirement {
        doc
        /*
         * The angle calculator shall apply temperature compensation
         * to the final angular position measurement.
         */
        subject rvdt: RVDTAssembly;
        constraint { rvdt.angleCalculator.temperature == rvdt.operatingTemp }
    }
}
