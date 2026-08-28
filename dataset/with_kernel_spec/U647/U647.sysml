package DepthGaugeModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    import Definitions::*;

    package Definitions {
        attribute def WaterDensityValue :> Real;
        attribute def VoltageValue :> Real;
        attribute def ChargeLevelValue :> Real;

        enum def OperatingMode {
            off;
            initializing;
            measuring;
            alarm;
        }
        enum def AlertType {
            none;
            warning;
            critical;
        }

        item def PressureReading {
            attribute pressure :> ISQ::pressure;
            attribute temperature :> ISQ::temperature;
        }
        item def DepthData {
            attribute depth :> ISQ::length;
            attribute temperature :> ISQ::temperature;
            attribute mode : OperatingMode;
            attribute alert : AlertType;
        }

        attribute def PowerOnSignal;
        attribute def PowerOffSignal;
        attribute def InitCompleteSignal;
        attribute def AlarmClearSignal;

        port def PressureDataOutPort {
            out pressureReading : PressureReading;
        }
        port def PressureDataInPort {
            in pressureReading : PressureReading;
        }
        port def DepthDataOutPort {
            out depthData : DepthData;
        }
        port def DepthDataInPort {
            in depthData : DepthData;
        }
        port def PowerOutPort {
            out voltage : VoltageValue;
        }
        port def PowerInPort {
            in voltage : VoltageValue;
        }

        action def Initialize;
        action def SelfTest;
        action def Calibrate;
        action def InitSequence;
        action def MeasureCycle;
        action def SensePressure {
            out pressure :> ISQ::pressure;
            out temperature :> ISQ::temperature;
        }
        action def CalculateDepth {
            in measuredPressure :> ISQ::pressure;
            in atmosphericPressure :> ISQ::pressure;
            in waterDensity : WaterDensityValue;
            out depth :> ISQ::length;
        }
        action def CheckDepthLimits {
            in depth :> ISQ::length;
            in warningDepth :> ISQ::length;
            in criticalDepth :> ISQ::length;
            out alert : AlertType;
        }
        action def UpdateDisplay {
            in depthData : DepthData;
        }

        state def OperatingStates;

        part def TitaniumHousing {
            attribute ratedDepth :> ISQ::length;
            attribute material : String = "Titanium";
        }

        part def Battery {
            attribute nominalVoltage : VoltageValue;
            attribute chargeLevel : ChargeLevelValue;
            port powerOut : PowerOutPort;
        }

        part def PressureSensor {
            port pressureDataOut : PressureDataOutPort;
            perform action sensePressure : SensePressure;
        }

        part def Processor {
            port pressureDataIn : PressureDataInPort;
            port displayDataOut : DepthDataOutPort;
            port powerIn : PowerInPort;
            attribute atmosphericPressure :> ISQ::pressure;
            attribute waterDensity : WaterDensityValue;
            attribute warningDepth :> ISQ::length;
            attribute criticalDepth :> ISQ::length;
            attribute currentDepth :> ISQ::length;
            attribute operatingMode : OperatingMode = OperatingMode::off;
            attribute alert : AlertType = AlertType::none;
            perform action calculateDepth : CalculateDepth;
            perform action checkDepthLimits : CheckDepthLimits;
        }

        part def DisplayUnit {
            port displayDataIn : DepthDataInPort;
            port powerIn : PowerInPort;
            perform action updateDisplay : UpdateDisplay;
        }

        part def DepthGauge {
            attribute maxOperatingDepth :> ISQ::length;
            attribute operatingMode : OperatingMode = OperatingMode::off;
            attribute alert : AlertType = AlertType::none;
            perform action initialize : Initialize;
            perform action selfTest : SelfTest;
            perform action calibrate : Calibrate;
            perform action sensePressure : SensePressure;
            perform action calculateDepth : CalculateDepth;
            perform action checkDepthLimits : CheckDepthLimits;
            perform action updateDisplay : UpdateDisplay;
            exhibit state operatingStates : OperatingStates;
            part housing : TitaniumHousing;
            part battery : Battery;
            part pressureSensor : PressureSensor;
            part processor : Processor;
            part display : DisplayUnit;
        }

        requirement def DepthAccuracyRequirement {
            doc /* The depth gauge shall measure depth with an accuracy of at least 0.5 m. */
            attribute requiredAccuracy :> ISQ::length = 0.5 [m];
        }
        requirement def HousingRatingRequirement {
            doc /* The titanium housing shall be rated for at least twice the maximum operating depth. */
            attribute safetyFactor : Real = 2.0;
        }
        requirement def DepthWarningRequirement {
            doc /* The device shall enter alarm state when depth exceeds the warning depth. */
        }
        requirement def DepthCriticalRequirement {
            doc /* The device shall send a critical alert when depth exceeds the critical depth. */
        }
        requirement def BatteryLifeRequirement {
            doc /* The battery shall last for at least 8 hours of continuous operation. */
            attribute minBatteryLifeHours : Real = 8.0;
        }
        requirement def WaterproofRequirement {
            doc /* The housing shall be waterproof and rated for depths significantly greater than the operating range. */
        }
    }

    package Usages {
        private import Definitions::*;

        action initialize : Initialize;
        action selfTest : SelfTest;
        action calibrate : Calibrate;
        action sensePressure : SensePressure;
        action calculateDepth : CalculateDepth;
        action checkDepthLimits : CheckDepthLimits;
        action updateDisplay : UpdateDisplay;

        action initSequence : InitSequence {
            do selfTest;
            do calibrate;
        }

        action measureCycle : MeasureCycle {
            do sensePressure;
            do calculateDepth;
            do checkDepthLimits;
            do updateDisplay;
        }

        state operatingStates : OperatingStates {
            entry; then off;

            state off;
            accept PowerOnSignal
                then initializing;

            state initializing {
                entry initialize;
                do initSequence;
            }
            accept InitCompleteSignal
                then measuring;
            accept PowerOffSignal
                then off;

            state measuring {
                do measureCycle;
            }
            accept when checkDepthLimits.alert == AlertType::warning
                then alarm;
            accept when checkDepthLimits.alert == AlertType::critical
                then alarm;
            accept PowerOffSignal
                then off;

            state alarm {
                do measureCycle;
            }
            accept when checkDepthLimits.alert == AlertType::none
                then measuring;
            accept AlarmClearSignal
                then measuring;
            accept PowerOffSignal
                then off;
        }

        part depthGaugeSystem : DepthGauge {
            attribute :>> maxOperatingDepth = 50 [m];

            part :>> housing : TitaniumHousing {
                attribute :>> ratedDepth = 100 [m];
            }

            part :>> battery : Battery {
                attribute :>> nominalVoltage = 3.7;
                attribute :>> chargeLevel = 100;
            }

            part :>> processor : Processor {
                attribute :>> atmosphericPressure = 101325 [Pa];
                attribute :>> waterDensity = 1025;
                attribute :>> warningDepth = 30 [m];
                attribute :>> criticalDepth = 40 [m];
            }

            flow pressureFlow of PressureReading
                from pressureSensor.pressureDataOut.pressureReading
                to processor.pressureDataIn.pressureReading;
            flow depthDataFlow of DepthData
                from processor.displayDataOut.depthData
                to display.displayDataIn.depthData;
            flow powerFlowToProcessor of VoltageValue
                from battery.powerOut.voltage
                to processor.powerIn.voltage;
            flow powerFlowToDisplay of VoltageValue
                from battery.powerOut.voltage
                to display.powerIn.voltage;
        }

        requirement depthAccuracyReq : DepthAccuracyRequirement;
        requirement housingRatingReq : HousingRatingRequirement;
        requirement depthWarningReq : DepthWarningRequirement;
        requirement depthCriticalReq : DepthCriticalRequirement;
        requirement batteryLifeReq : BatteryLifeRequirement;
        requirement waterproofReq : WaterproofRequirement;
    }
}
