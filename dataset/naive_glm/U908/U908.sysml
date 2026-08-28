package TestLightModel {
    import ScalarValues::*;
    
    package Units {
        unit V;
        unit A;
        unit ohm;
        unit W;
        unit lm;
        unit m;
        unit degC;
        unit s;
    }
    
    value type Voltage :> Real { unit Units::V; }
    value type Current :> Real { unit Units::A; }
    value type Resistance :> Real { unit Units::ohm; }
    value type Power :> Real { unit Units::W; }
    value type Brightness :> Real { unit Units::lm; }
    value type Length :> Real { unit Units::m; }
    value type Temperature :> Real { unit Units::degC; }
    
    enum TestResult { none, voltagePresent, continuity, openCircuit, voltageDrop }
    
    item def ElectricalEnergy;
    
    port def ElectricalPort {
        in voltage : Voltage;
        out current : Current;
    }
    
    part def InsulatedHandle {
        attribute material : String = "Rubber";
        attribute insulationRating : Voltage = 1000 [V];
        attribute length : Length = 0.15 [m];
        attribute maxOperatingTemp : Temperature = 80 [degC];
    }
    
    part def WireLead {
        attribute length : Length = 0.5 [m];
        attribute flexibility : String = "Flexible";
        attribute conductorResistance : Resistance = 0.05 [ohm];
        port endA : ElectricalPort;
        port endB : ElectricalPort;
    }
    
    part def Probe {
        attribute material : String = "Steel";
        attribute tipType : String = "Sharp";
        attribute contactResistance : Resistance = 0.01 [ohm];
        port connection : ElectricalPort;
    }
    
    part def IncandescentLamp {
        attribute ratedVoltage : Voltage = 12 [V];
        attribute ratedPower : Power = 2 [W];
        attribute filamentResistance : Resistance = 72 [ohm];
        attribute maxBrightness : Brightness = 80 [lm];
        attribute currentBrightness : Brightness = 0 [lm];
        attribute isIlluminated : Boolean = false;
        
        port terminalA : ElectricalPort;
        port terminalB : ElectricalPort;
        
        action def Illuminate {
            in appliedVoltage : Voltage;
            in seriesResistance : Resistance;
            out brightness : Brightness;
            out current : Current;
            
            private attribute effectiveR : Resistance = filamentResistance + seriesResistance;
            private attribute computedCurrent : Current = appliedVoltage / effectiveR;
            private attribute computedPower : Power = computedCurrent * computedCurrent * filamentResistance;
            
            if computedPower > 0 [W] {
                brightness = (computedPower / (ratedVoltage * ratedVoltage / filamentResistance)) * maxBrightness;
                current = computedCurrent;
            } else {
                brightness = 0 [lm];
                current = 0 [A];
            }
        }
        
        perform action illuminate : Illuminate;
    }
    
    part def CurrentLimitingResistor {
        attribute resistance : Resistance = 100 [ohm];
        attribute powerRating : Power = 1 [W];
        attribute tolerance : Real = 0.05;
        port terminalA : ElectricalPort;
        port terminalB : ElectricalPort;
    }
    
    part def CircuitUnderTest {
        attribute openCircuitVoltage : Voltage = 0 [V];
        attribute internalResistance : Resistance = 0 [ohm];
        attribute isComplete : Boolean = false;
        port terminalA : ElectricalPort;
        port terminalB : ElectricalPort;
    }
    
    part def TestLight {
        attribute deviceName : String = "Handheld Electrical Test Light";
        attribute maxRatedVoltage : Voltage = 24 [V];
        attribute thresholdBright : Voltage = 10 [V];
        attribute thresholdDim : Voltage = 3 [V];
        attribute brightLumenLevel : Brightness = 50 [lm];
        
        part handle : InsulatedHandle;
        part lead1 : WireLead;
        part lead2 : WireLead;
        part probe1 : Probe;
        part probe2 : Probe;
        part lamp : IncandescentLamp;
        part resistor : CurrentLimitingResistor;
        
        port probeTip1 : ElectricalPort;
        port probeTip2 : ElectricalPort;
        
        attribute measuredVoltage : Voltage = 0 [V];
        attribute detectedResult : TestResult = TestResult::none;
        
        connect probeTip1 to probe1.connection;
        connect probe1.connection to lead1.endB;
        connect lead1.endA to lamp.terminalA;
        connect lamp.terminalB to resistor.terminalA;
        connect resistor.terminalB to lead2.endA;
        connect lead2.endB to probe2.connection;
        connect probe2.connection to probeTip2;
        
        action def PerformTest {
            in probe1Voltage : Voltage;
            in probe2Voltage : Voltage;
            in circuitComplete : Boolean;
            out result : TestResult;
            out lampBrightness : Brightness;
            out lampCurrent : Current;
            
            private attribute voltageDiff : Voltage = probe1Voltage - probe2Voltage;
            
            if not circuitComplete {
                result = TestResult::openCircuit;
                lampBrightness = 0 [lm];
                lampCurrent = 0 [A];
            } else if voltageDiff <= 0 [V] {
                result = TestResult::none;
                lampBrightness = 0 [lm];
                lampCurrent = 0 [A];
            } else {
                lamp.illuminate(appliedVoltage = voltageDiff, seriesResistance = resistor.resistance);
                lampBrightness = lamp.illuminate.brightness;
                lampCurrent = lamp.illuminate.current;
                if lampBrightness >= brightLumenLevel {
                    result = TestResult::voltagePresent;
                } else if lampBrightness > 0 [lm] {
                    result = TestResult::voltageDrop;
                } else {
                    result = TestResult::continuity;
                }
            }
        }
        
        perform action performTest : PerformTest;
        
        state def TestLightStates {
            entry;
            state off {
                entry;
                lamp.isIlluminated = false;
                lamp.currentBrightness = 0 [lm];
                detectedResult = TestResult::none;
            }
            
            state testing {
                entry;
                perform performTest(
                    probe1Voltage = probeTip1.voltage,
                    probe2Voltage = probeTip2.voltage,
                    circuitComplete = (probeTip1.voltage != probeTip2.voltage)
                );
                lamp.currentBrightness = performTest.lampBrightness;
                detectedResult = performTest.result;
                
                state lampOff {
                    entry;
                    lamp.isIlluminated = false;
                }
                state lampDim {
                    entry;
                    lamp.isIlluminated = true;
                }
                state lampBright {
                    entry;
                    lamp.isIlluminated = true;
                }
                
                transition lampOff to lampDim
                    when lamp.currentBrightness > 0 [lm] and lamp.currentBrightness < brightLumenLevel;
                transition lampDim to lampBright
                    when lamp.currentBrightness >= brightLumenLevel;
                transition lampBright to lampDim
                    when lamp.currentBrightness < brightLumenLevel and lamp.currentBrightness > 0 [lm];
                transition lampDim to lampOff
                    when lamp.currentBrightness == 0 [lm];
                transition lampBright to lampOff
                    when lamp.currentBrightness == 0 [lm];
            }
            
            transition off to testing
                when probeTip1.voltage != probeTip2.voltage;
            transition testing to off
                when probeTip1.voltage == probeTip2.voltage;
        }
        
        perform state testLightBehavior : TestLightStates;
    }
    
    requirement def VoltageDetectionRequirement {
        subject testLight : TestLight;
        require {
            testLight.lamp.currentBrightness > 0 [lm]
                when testLight.probeTip1.voltage - testLight.probeTip2.voltage > 0 [V];
        }
        require {
            testLight.lamp.currentBrightness == 0 [lm]
                when testLight.probeTip1.voltage - testLight.probeTip2.voltage <= 0 [V];
        }
    }
    
    requirement def ContinuityRequirement {
        subject testLight : TestLight;
        require {
            testLight.detectedResult == TestResult::openCircuit
                implies testLight.lamp.currentBrightness == 0 [lm];
        }
        require {
            testLight.detectedResult == TestResult::continuity
                implies testLight.lamp.currentBrightness > 0 [lm];
        }
    }
    
    requirement def SafetyRequirement {
        subject testLight : TestLight;
        require { testLight.handle.insulationRating >= 1000 [V]; }
        require { testLight.handle.material == "Rubber"; }
        require { testLight.maxRatedVoltage <= 24 [V]; }
        require { testLight.resistor.powerRating >= 1 [W]; }
    }
    
    requirement def BrightnessIndicationRequirement {
        subject testLight : TestLight;
        require {
            testLight.lamp.currentBrightness >= testLight.brightLumenLevel
                implies testLight.detectedResult == TestResult::voltagePresent;
        }
        require {
            testLight.lamp.currentBrightness > 0 [lm]
                and testLight.lamp.currentBrightness < testLight.brightLumenLevel
                implies testLight.detectedResult == TestResult::voltageDrop;
        }
        require {
            testLight.lamp.currentBrightness == 0 [lm]
                implies testLight.detectedResult == TestResult::none
                or testLight.detectedResult == TestResult::openCircuit;
        }
    }
    
    requirement def ProbeContactRequirement {
        subject testLight : TestLight;
        require { testLight.probe1.tipType == "Sharp"; }
        require { testLight.probe2.tipType == "Sharp"; }
        require { testLight.probe1.contactResistance < 0.1 [ohm]; }
        require { testLight.probe2.contactResistance < 0.1 [ohm]; }
    }
    
    requirement def SeriesCircuitRequirement {
        subject testLight : TestLight;
        require {
            testLight.lamp.filamentResistance + testLight.resistor.resistance
                limits current through testLight.lamp to safe operating range;
        }
        require { testLight.resistor.resistance == 100 [ohm]; }
    }
    
    part def TestLightSystem {
        part testLight : TestLight;
        part circuit : CircuitUnderTest;
        
        connect testLight.probeTip1 to circuit.terminalA;
        connect testLight.probeTip2 to circuit.terminalB;
        
        satisfy voltageDetection : VoltageDetectionRequirement by testLight;
        satisfy continuity : ContinuityRequirement by testLight;
        satisfy safety : SafetyRequirement by testLight;
        satisfy brightnessIndication : BrightnessIndicationRequirement by testLight;
        satisfy probeContact : ProbeContactRequirement by testLight;
        satisfy seriesCircuit : SeriesCircuitRequirement by testLight;
    }
}
