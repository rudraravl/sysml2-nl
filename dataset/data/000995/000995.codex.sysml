package BourdonGaugeSystemModel {

    import ScalarValues::*;
    import ISQ::*;

    attribute def PressureValue :> Real {
        unit = "kPa";
    }

    attribute def AngleValue :> Real {
        unit = "deg";
    }

    attribute def TorqueValue :> Real {
        unit = "N*m";
    }

    attribute def LengthValue :> Real {
        unit = "mm";
    }

    attribute def RatioValue :> Real;

    attribute def TimeValue :> Real {
        unit = "s";
    }

    item def ProcessFluid {
        attribute pressure : PressureValue;
        attribute temperature : Real {
            unit = "degC";
        }
    }

    item def MechanicalDisplacement {
        attribute tipTravel : LengthValue;
        attribute angularDeflection : AngleValue;
    }

    item def GaugeReading {
        attribute indicatedPressure : PressureValue;
        attribute pointerAngle : AngleValue;
        attribute timestamp : TimeValue;
    }

    port def PressureInletPort {
        in item fluid : ProcessFluid;
    }

    port def DisplacementPort {
        out item displacement : MechanicalDisplacement;
    }

    port def MotionInputPort {
        in item displacement : MechanicalDisplacement;
    }

    port def RotationalMotionPort {
        out item rotation : MechanicalDisplacement;
    }

    port def ReadingPort {
        out item reading : GaugeReading;
    }

    action def ConvertPressureToTubeMotion {
        in pressure : PressureValue;
        out displacement : MechanicalDisplacement;

        attribute tubeSensitivity : Real = 0.018;
        attribute maxTipTravel : LengthValue = 6.0;

        action computeTipTravel;
        action limitTravel;
    }

    action def AmplifyMotion {
        in displacement : MechanicalDisplacement;
        out amplifiedMotion : MechanicalDisplacement;

        attribute linkageRatio : RatioValue = 4.8;
        attribute sectorGearRatio : RatioValue = 2.6;
    }

    action def IndicatePressure {
        in amplifiedMotion : MechanicalDisplacement;
        out reading : GaugeReading;

        attribute dialStartAngle : AngleValue = 35.0;
        attribute dialSweepAngle : AngleValue = 270.0;
        attribute pressureRangeMaximum : PressureValue = 1000.0;
    }

    state def GaugeOperatingState {
        entry action initializeGauge;

        state Unpressurized;
        state Measuring;
        state Overpressure;
        state ReturningToZero;
        state Faulted;

        transition first Unpressurized;
        transition Unpressurized_to_Measuring
            first Unpressurized
            then Measuring;

        transition Measuring_to_Overpressure
            first Measuring
            then Overpressure;

        transition Measuring_to_ReturningToZero
            first Measuring
            then ReturningToZero;

        transition ReturningToZero_to_Unpressurized
            first ReturningToZero
            then Unpressurized;

        transition Overpressure_to_Faulted
            first Overpressure
            then Faulted;
    }

    part def BourdonTube {
        port pressureIn : PressureInletPort;
        port tipMotionOut : DisplacementPort;

        attribute materialYieldPressure : PressureValue = 1500.0;
        attribute proofPressure : PressureValue = 1300.0;
        attribute nominalRangeMaximum : PressureValue = 1000.0;
        attribute tubeArcRadius : LengthValue = 42.0;
        attribute tubeWallThickness : LengthValue = 0.45;
        attribute tubeTipTravelAtFullScale : LengthValue = 5.4;

        perform action pressureToMotion : ConvertPressureToTubeMotion;
    }

    part def LinkageMechanism {
        port motionIn : MotionInputPort;
        port motionOut : RotationalMotionPort;

        attribute linkLength : LengthValue = 18.0;
        attribute pivotFrictionTorque : TorqueValue = 0.004;
        attribute motionAmplificationRatio : RatioValue = 4.8;

        perform action amplify : AmplifyMotion;
    }

    part def SectorGearAndPinion {
        port motionIn : MotionInputPort;
        port pointerMotionOut : RotationalMotionPort;

        attribute sectorRadius : LengthValue = 14.0;
        attribute pinionRadius : LengthValue = 2.8;
        attribute gearRatio : RatioValue = 5.0;
        attribute backlashAngle : AngleValue = 0.4;
    }

    part def Pointer {
        port rotationIn : MotionInputPort;
        port readingOut : ReadingPort;

        attribute length : LengthValue = 38.0;
        attribute zeroAngle : AngleValue = 35.0;
        attribute fullScaleAngle : AngleValue = 305.0;
        attribute inertia : Real {
            unit = "g*mm^2";
        } = 21.0;

        perform action indicate : IndicatePressure;
    }

    part def Dial {
        attribute minimumPressure : PressureValue = 0.0;
        attribute maximumPressure : PressureValue = 1000.0;
        attribute majorGraduationInterval : PressureValue = 100.0;
        attribute minorGraduationInterval : PressureValue = 20.0;
        attribute sweepAngle : AngleValue = 270.0;
        attribute unitLabel : String = "kPa";
    }

    part def Case {
        attribute bezelDiameter : LengthValue = 100.0;
        attribute caseDepth : LengthValue = 42.0;
        attribute ingressProtectionRating : String = "IP54";
    }

    part def Socket {
        port processConnection : PressureInletPort;

        attribute threadDesignation : String = "1/4 NPT";
        attribute boreDiameter : LengthValue = 3.0;
        attribute maximumWorkingPressure : PressureValue = 1000.0;
    }

    part def BourdonPressureGauge {
        port processPressureIn : PressureInletPort;
        port indicatedReadingOut : ReadingPort;

        attribute measurementRangeMin : PressureValue = 0.0;
        attribute measurementRangeMax : PressureValue = 1000.0;
        attribute accuracyClassPercentFullScale : Real = 1.6;
        attribute overpressureLimit : PressureValue = 1300.0;
        attribute burstPressureMinimum : PressureValue = 3000.0;
        attribute responseTime : TimeValue = 0.35;

        part socket : Socket;
        part bourdonTube : BourdonTube;
        part linkage : LinkageMechanism;
        part sectorGearAndPinion : SectorGearAndPinion;
        part pointer : Pointer;
        part dial : Dial;
        part caseAssembly : Case;

        connection pressurePath1
            connect processPressureIn to socket.processConnection;

        connection pressurePath2
            connect socket.processConnection to bourdonTube.pressureIn;

        connection tubeToLinkage
            connect bourdonTube.tipMotionOut to linkage.motionIn;

        connection linkageToGear
            connect linkage.motionOut to sectorGearAndPinion.motionIn;

        connection gearToPointer
            connect sectorGearAndPinion.pointerMotionOut to pointer.rotationIn;

        connection readingOutput
            connect pointer.readingOut to indicatedReadingOut;

        perform action measurePressure {
            first start;
            then receiveProcessPressure;
            then convertTubeElasticDeformation;
            then amplifyDeflection;
            then rotatePointer;
            then publishIndicatedReading;
        }

        exhibit state gaugeState : GaugeOperatingState;
    }

    requirement def PrimaryFunctionRequirement {
        subject gauge : BourdonPressureGauge;

        doc
        /*
         * The Bourdon pressure gauge shall convert static pressure of a process fluid
         * entering the socket into elastic deformation of a curved Bourdon tube,
         * mechanically amplify the tube-tip displacement through linkage and gearing,
         * and present the corresponding pressure as an analog pointer position on a
         * calibrated dial.
         */

        require constraint {
            gauge.measurementRangeMin == 0.0 and
            gauge.measurementRangeMax == 1000.0
        }
    }

    requirement def AccuracyRequirement {
        subject gauge : BourdonPressureGauge;

        doc
        /*
         * The indicated pressure shall remain within plus or minus 1.6 percent of
         * full-scale span when the applied pressure is within the calibrated range.
         */

        attribute allowedError : PressureValue = 16.0;

        require constraint {
            gauge.accuracyClassPercentFullScale <= 1.6
        }
    }

    requirement def OverpressureRequirement {
        subject gauge : BourdonPressureGauge;

        doc
        /*
         * The gauge shall tolerate temporary pressure up to 130 percent of full scale
         * without permanent loss of indication function.
         */

        require constraint {
            gauge.overpressureLimit >= 1300.0
        }
    }

    requirement def ReadabilityRequirement {
        subject gauge : BourdonPressureGauge;

        doc
        /*
         * The dial and pointer shall provide a continuous analog indication over a
         * minimum angular sweep of 270 degrees from zero to full-scale pressure.
         */

        require constraint {
            gauge.dial.sweepAngle >= 270.0
        }
    }

    part bourdonGaugeSystem {
        part gauge : BourdonPressureGauge;

        item ambientProcessFluid : ProcessFluid {
            attribute pressure = 0.0;
            attribute temperature = 22.0;
        }

        item fullScaleProcessFluid : ProcessFluid {
            attribute pressure = 1000.0;
            attribute temperature = 22.0;
        }

        satisfy PrimaryFunctionRequirement by gauge;
        satisfy AccuracyRequirement by gauge;
        satisfy OverpressureRequirement by gauge;
        satisfy ReadabilityRequirement by gauge;
    }
}