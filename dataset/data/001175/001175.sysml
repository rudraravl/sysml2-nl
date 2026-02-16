package PellistorGasDetectionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def GasConcentrationValue :> Real {
        doc /* Gas concentration expressed as percentage of Lower Explosive Limit (%LEL) */
    }

    attribute def ResistanceValue :> ISQ::resistance;
    attribute def TemperatureValue :> ISQ::temperature;
    attribute def VoltageValue :> ISQ::voltage;
    attribute def CurrentValue :> ISQ::current;
    attribute def TimeValue :> ISQ::duration;

    item def CombustibleGas {
        attribute concentration : GasConcentrationValue;
        attribute gasType : String;
    }

    item def BridgeSignal {
        attribute voltage : VoltageValue;
        attribute timestamp : TimeValue;
    }

    port def GasExposurePort {
        in item exposedGas : CombustibleGas;
    }

    port def ElectricalPort {
        inout attribute voltage : VoltageValue;
        inout attribute current : CurrentValue;
    }

    port def SignalPort {
        out item signal : BridgeSignal;
    }

    port def AlarmPort {
        out attribute alarmActive : Boolean;
    }

    part def CatalyticBead {
        doc /* Active bead with platinum catalyst that oxidizes combustible gas, causing temperature and resistance increase */
        
        attribute baseResistance : ResistanceValue;
        attribute operatingTemperature : TemperatureValue;
        attribute currentResistance : ResistanceValue;
        
        port gasExposure : GasExposurePort;
        port electrical : ElectricalPort;
        
        action def CatalyticOxidation {
            in gasConcentration : GasConcentrationValue;
            in ambientTemp : TemperatureValue;
            out temperatureRise : TemperatureValue;
            out resistanceChange : ResistanceValue;
            doc /* Models exothermic oxidation reaction on catalyst surface */
        }
    }

    part def CompensationBead {
        doc /* Reference bead without catalyst, compensates for ambient temperature and humidity changes */
        
        attribute baseResistance : ResistanceValue;
        attribute operatingTemperature : TemperatureValue;
        attribute currentResistance : ResistanceValue;
        
        port electrical : ElectricalPort;
    }

    part def WheatstoneBridge {
        doc /* Balanced bridge circuit that converts resistance change to voltage output */
        
        attribute supplyVoltage : VoltageValue;
        attribute balanceVoltage : VoltageValue;
        
        port powerInput : ElectricalPort;
        port signalOutput : SignalPort;
        
        part activeLeg : CatalyticBead;
        part referenceLeg : CompensationBead;
        part fixedResistor1 {
            attribute resistance : ResistanceValue;
        }
        part fixedResistor2 {
            attribute resistance : ResistanceValue;
        }
        
        action def MeasureBridgeImbalance {
            in catalyticResistance : ResistanceValue;
            in referenceResistance : ResistanceValue;
            in r1 : ResistanceValue;
            in r2 : ResistanceValue;
            in supply : VoltageValue;
            out outputVoltage : VoltageValue;
            doc /* Calculates differential voltage across bridge diagonal */
        }
    }

    part def SignalConditioner {
        doc /* Amplifies and filters bridge output signal */
        
        attribute gain : Real;
        attribute filterCutoff : Real;
        
        port input : SignalPort;
        port output : SignalPort;
        
        action def AmplifyAndFilter {
            in rawSignal : VoltageValue;
            in amplificationGain : Real;
            out conditionedSignal : VoltageValue;
        }
    }

    part def ConcentrationCalculator {
        doc /* Converts conditioned voltage to gas concentration reading */
        
        attribute calibrationSlope : Real;
        attribute calibrationOffset : VoltageValue;
        
        port voltageInput : SignalPort;
        
        action def CalculateConcentration {
            in signalVoltage : VoltageValue;
            in slope : Real;
            in offset : VoltageValue;
            out concentration : GasConcentrationValue;
        }
    }

    part def AlarmController {
        doc /* Monitors concentration and activates alarm at threshold */
        
        attribute warningThreshold : GasConcentrationValue;
        attribute alarmThreshold : GasConcentrationValue;
        attribute currentReading : GasConcentrationValue;
        
        port alarmOutput : AlarmPort;
        
        state def AlarmStateMachine {
            entry; then normal;
            
            state normal {
                doc /* No hazardous gas detected */
            }
            
            state warning {
                doc /* Gas concentration approaching hazardous level */
            }
            
            state alarm {
                doc /* Hazardous gas concentration detected */
            }
            
            transition normalToWarning
                first normal
                if currentReading >= warningThreshold and currentReading < alarmThreshold
                then warning;
            
            transition warningToAlarm
                first warning
                if currentReading >= alarmThreshold
                then alarm;
            
            transition alarmToWarning
                first alarm
                if currentReading < alarmThreshold and currentReading >= warningThreshold
                then warning;
            
            transition warningToNormal
                first warning
                if currentReading < warningThreshold
                then normal;
            
            transition alarmToNormal
                first alarm
                if currentReading < warningThreshold
                then normal;
        }
    }

    part def PellistorSensor {
        doc /* Catalytic combustible gas sensor using matched bead pair in Wheatstone bridge configuration */
        
        attribute sensorRange : GasConcentrationValue[2];
        attribute responseTime : TimeValue;
        attribute warmupTime : TimeValue;
        
        port gasInput : GasExposurePort;
        port powerSupply : ElectricalPort;
        port sensorOutput : SignalPort;
        
        part bridge : WheatstoneBridge {
            perform sensingCycle.measureBridge;
        }
        
        part conditioner : SignalConditioner {
            perform sensingCycle.conditionSignal;
        }
        
        connection bridgeToConditioner connect bridge.signalOutput to conditioner.input;
        connection conditionerToOutput connect conditioner.output to sensorOutput;
        connection gasToActiveBead connect gasInput to bridge.activeLeg.gasExposure;
        
        action sensingCycle {
            first start;
            
            then action heatBeads {
                doc /* Apply power to heat both beads to operating temperature */
            }
            
            then merge continuousSensing;
            
            then action exposeToCombustibleGas {
                doc /* Ambient gas contacts catalytic bead surface */
            }
            
            then action oxidize : bridge.activeLeg::CatalyticOxidation {
                in gasConcentration = gasInput.exposedGas.concentration;
                in ambientTemp = bridge.activeLeg.operatingTemperature;
                out temperatureRise;
                out resistanceChange;
            }
            
            then action updateResistance {
                doc /* Update catalytic bead resistance based on oxidation heat */
            }
            
            then action measureBridge : bridge::MeasureBridgeImbalance {
                in catalyticResistance = bridge.activeLeg.currentResistance;
                in referenceResistance = bridge.referenceLeg.currentResistance;
                in r1 = bridge.fixedResistor1.resistance;
                in r2 = bridge.fixedResistor2.resistance;
                in supply = bridge.supplyVoltage;
                out outputVoltage;
            }
            
            then action conditionSignal : conditioner::AmplifyAndFilter {
                in rawSignal = measureBridge.outputVoltage;
                in amplificationGain = conditioner.gain;
                out conditionedSignal;
            }
            
            then action transmitSignal {
                doc /* Output conditioned signal for processing */
            }
            
            then continuousSensing;
        }
    }

    part def GasDetectionSystem {
        doc /* Complete combustible gas detection system using pellistor technology for industrial safety monitoring */
        
        part sensor : PellistorSensor {
            sensorRange = (0.0, 100.0);
            responseTime = 10.0 [SI::s];
            warmupTime = 30.0 [SI::s];
        }
        
        part calculator : ConcentrationCalculator {
            perform monitoringCycle.calculateConcentration;
        }
        
        part alarmUnit : AlarmController {
            warningThreshold = 20.0;
            alarmThreshold = 50.0;
        }
        
        part powerModule {
            attribute outputVoltage : VoltageValue;
            port powerOut : ElectricalPort;
        }
        
        connection powerToPellistor connect powerModule.powerOut to sensor.powerSupply;
        connection sensorToCalculator connect sensor.sensorOutput to calculator.voltageInput;
        
        action monitoringCycle {
            first start;
            
            then action warmup {
                doc /* Allow sensor to reach stable operating temperature */
            }
            
            then merge continuousMonitoring;
            
            then action acquireSignal {
                doc /* Read voltage signal from pellistor sensor */
            }
            
            then action calculateConcentration : calculator::CalculateConcentration {
                in signalVoltage = sensor.sensorOutput.signal.voltage;
                in slope = calculator.calibrationSlope;
                in offset = calculator.calibrationOffset;
                out concentration;
            }
            
            then action evaluateThresholds {
                doc /* Compare concentration against alarm thresholds */
            }
            
            then decide;
                if calculateConcentration.concentration >= alarmUnit.alarmThreshold then activateAlarm;
                if calculateConcentration.concentration < alarmUnit.alarmThreshold then maintainMonitoring;
            
            action activateAlarm {
                doc /* Trigger alarm output for hazardous gas condition */
            }
            then continuousMonitoring;
            
            action maintainMonitoring {
                doc /* Continue normal monitoring operation */
            }
            then continuousMonitoring;
        }
    }

    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;

    requirement <'PELL-REQ-001'> primaryFunction {
        doc /* The pellistor-based gas detection system shall detect the presence of combustible gases 
               in ambient air through catalytic oxidation and provide continuous concentration monitoring 
               with automatic alarm activation when hazardous levels are exceeded. */
        
        subject system : GasDetectionSystem;
        
        assume constraint combustibleGasPresent {
            doc /* Combustible gas is present in the monitored environment */
        }
        
        require constraint detectAndOxidize {
            doc /* System shall oxidize combustible gas on catalytic bead surface */
        }
        
        require constraint continuousMonitoring {
            doc /* System shall continuously monitor gas concentration */
        }
        
        require constraint alarmActivation {
            doc /* System shall activate alarm when concentration exceeds threshold */
            system.alarmUnit.alarmThreshold <= 50.0
        }
    }

    requirement <'PELL-REQ-002'> responseTimeRequirement : PerformanceRequirement {
        doc /* The sensor shall respond to gas presence within specified time limit */
        
        subject sensor : PellistorSensor;
        
        require constraint responseLimit {
            sensor.responseTime <= 15.0 [SI::s]
        }
    }

    requirement <'PELL-REQ-003'> detectionRangeRequirement : PerformanceRequirement {
        doc /* The sensor shall detect gas concentrations across full operational range */
        
        subject sensor : PellistorSensor;
        
        require constraint rangeSpecification {
            sensor.sensorRange[1] == 0.0 and
            sensor.sensorRange[2] >= 100.0
        }
    }

    requirement <'PELL-REQ-004'> safetyAlarmRequirement : SafetyRequirement {
        doc /* The system shall provide multi-level alarm capability for operator safety */
        
        subject system : GasDetectionSystem;
        
        require constraint warningLevel {
            system.alarmUnit.warningThreshold >= 20.0
        }
        
        require constraint alarmLevel {
            system.alarmUnit.alarmThreshold >= 50.0
        }
    }
}
