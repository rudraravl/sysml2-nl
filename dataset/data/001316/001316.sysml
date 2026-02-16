package 'Wheatstone Bridge System' {
    private import ISQ::*;
    private import ScalarValues::*;
    
    port def ElectricalTerminal {
        attribute voltage : ISQ::VoltageValue;
        attribute current : ISQ::ElectricCurrentValue;
    }
    
    part def Resistor {
        attribute resistance : ISQ::ElectricResistanceValue;
        port terminal1 : ElectricalTerminal;
        port terminal2 : ElectricalTerminal;
    }
    
    part def VariableResistor :> Resistor {
        attribute minResistance : ISQ::ElectricResistanceValue;
        attribute maxResistance : ISQ::ElectricResistanceValue;
    }
    
    part def VoltageSource {
        attribute supplyVoltage : ISQ::VoltageValue;
        port positive : ElectricalTerminal;
        port negative : ElectricalTerminal;
    }
    
    part def Galvanometer {
        attribute sensitivity : ISQ::VoltageValue;
        attribute measuredVoltage : ISQ::VoltageValue;
        port input1 : ElectricalTerminal;
        port input2 : ElectricalTerminal;
    }
    
    action def MeasureBridgeVoltage {
        in r1Resistance : ISQ::ElectricResistanceValue;
        in r2Resistance : ISQ::ElectricResistanceValue;
        in r3Resistance : ISQ::ElectricResistanceValue;
        in rxResistance : ISQ::ElectricResistanceValue;
        in supplyVoltage : ISQ::VoltageValue;
        out bridgeVoltage : ISQ::VoltageValue;
    }
    
    action def CalculateUnknownResistance {
        in r1 : ISQ::ElectricResistanceValue;
        in r2 : ISQ::ElectricResistanceValue;
        in r3 : ISQ::ElectricResistanceValue;
        out rx : ISQ::ElectricResistanceValue;
    }
    
    part def WheatstoneBridge {
        doc /* A Wheatstone bridge is a precision electrical measurement circuit used to 
               determine unknown electrical resistance by balancing two legs of a bridge circuit. 
               When the bridge is balanced, the voltage difference between the midpoints is zero, 
               allowing precise calculation of the unknown resistance. */
        
        attribute supplyVoltage : ISQ::VoltageValue;
        attribute bridgeVoltage : ISQ::VoltageValue;
        attribute unknownResistance : ISQ::ElectricResistanceValue;
        
        part r1 : Resistor {
            doc /* Known reference resistor in first leg */
            attribute :>> resistance;
        }
        
        part r2 : Resistor {
            doc /* Known reference resistor in second leg */
            attribute :>> resistance;
        }
        
        part r3 : VariableResistor {
            doc /* Variable resistor adjusted to balance the bridge */
            attribute :>> resistance;
            attribute :>> minResistance;
            attribute :>> maxResistance;
        }
        
        part rx : Resistor {
            doc /* Unknown resistor being measured */
            attribute :>> resistance;
        }
        
        part source : VoltageSource {
            doc /* DC voltage source powering the bridge */
            attribute :>> supplyVoltage;
        }
        
        part detector : Galvanometer {
            doc /* Null detector measuring voltage difference between bridge midpoints */
            attribute :>> sensitivity;
            attribute :>> measuredVoltage;
        }
        
        connection sourceToR1 connect source.positive to r1.terminal1;
        connection sourceToR2 connect source.positive to r2.terminal1;
        connection r1ToR3 connect r1.terminal2 to r3.terminal1;
        connection r2ToRx connect r2.terminal2 to rx.terminal1;
        connection r3ToGround connect r3.terminal2 to source.negative;
        connection rxToGround connect rx.terminal2 to source.negative;
        connection detectorToMidpoint1 connect detector.input1 to r1.terminal2;
        connection detectorToMidpoint2 connect detector.input2 to r2.terminal2;
        
        perform action measureResistance[*] ordered references operateBridge;
    }
    
    action operateBridge {
        doc /* The Wheatstone bridge operates by comparing voltage drops across two parallel 
               resistive dividers. The bridge is balanced by adjusting the variable resistor 
               until the galvanometer reads zero voltage, at which point the unknown resistance 
               can be calculated from the known resistances using the balance equation. */
        
        first start;
        then merge continueBalancing;
        
        then action applyVoltage {
            doc /* Apply DC voltage across the bridge circuit */
        }
        
        then action measureBridgeVoltage : MeasureBridgeVoltage {
            in r1Resistance : ISQ::ElectricResistanceValue;
            in r2Resistance : ISQ::ElectricResistanceValue;
            in r3Resistance : ISQ::ElectricResistanceValue;
            in rxResistance : ISQ::ElectricResistanceValue;
            in supplyVoltage : ISQ::VoltageValue;
            out bridgeVoltage : ISQ::VoltageValue;
        }
        
        then decide;
            if measureBridgeVoltage.bridgeVoltage < 0.001 and measureBridgeVoltage.bridgeVoltage > -0.001 then balanced;
            if measureBridgeVoltage.bridgeVoltage >= 0.001 or measureBridgeVoltage.bridgeVoltage <= -0.001 then unbalanced;
        
        action balanced {
            doc /* Bridge is balanced when voltage difference is effectively zero */
            then action calculateResistance : CalculateUnknownResistance {
                doc /* Calculate unknown resistance using balance equation: Rx = R2 * R3 / R1 */
                in r1 : ISQ::ElectricResistanceValue;
                in r2 : ISQ::ElectricResistanceValue;
                in r3 : ISQ::ElectricResistanceValue;
                out rx : ISQ::ElectricResistanceValue;
            }
            then action recordMeasurement {
                doc /* Record the calculated resistance value */
            }
            then done;
        }
        
        action unbalanced {
            doc /* Bridge is unbalanced; adjust variable resistor to minimize voltage difference */
            then action adjustVariableResistor {
                doc /* Adjust R3 to reduce bridge voltage toward zero */
            }
            then continueBalancing;
        }
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* The bridge shall enable precise resistance measurement with minimal error. */
        subject bridge : WheatstoneBridge;
        
        assert constraint accuracyConstraint {
            doc /* Bridge voltage shall be measurable within sensitivity limits. */
            bridge.detector.measuredVoltage >= -bridge.detector.sensitivity and 
            bridge.detector.measuredVoltage <= bridge.detector.sensitivity
        }
    }
    
    requirement def BalanceConditionRequirement {
        doc /* The bridge shall achieve balance when resistance ratios are equal. */
        subject bridge : WheatstoneBridge;
        
        assert constraint balanceConstraint {
            doc /* At balance: R1/R2 = R3/Rx, therefore Rx = R2 * R3 / R1 */
            bridge.bridgeVoltage == 0.0 implies 
            (bridge.r1.resistance / bridge.r2.resistance) == 
            (bridge.r3.resistance / bridge.rx.resistance)
        }
    }
    
    requirement <'WB-SYS-001'> wheatstoneBridgeSystemRequirement {
        doc /* The Wheatstone bridge system shall accurately measure unknown electrical 
               resistance by balancing voltage across two parallel resistive dividers, 
               enabling determination of resistance values with high precision. */
        
        subject bridgeSystem : WheatstoneBridge;
        
        assume requirement measurementAccuracy : MeasurementAccuracyRequirement {
            subject bridge = bridgeSystem;
        }
        
        require requirement balanceCondition : BalanceConditionRequirement {
            subject bridge = bridgeSystem;
        }
    }
    
    part wheatstoneBridgeSystem : WheatstoneBridge {
        doc /* Complete Wheatstone bridge measurement system configured for precision 
               resistance measurement. The system uses a balanced bridge configuration 
               to determine unknown resistance values by comparing them against known 
               reference resistances. */
        
        attribute :>> supplyVoltage = 5.0;
        
        part :>> r1 {
            attribute :>> resistance = 1000.0;
        }
        
        part :>> r2 {
            attribute :>> resistance = 1000.0;
        }
        
        part :>> r3 {
            attribute :>> resistance = 750.0;
            attribute :>> minResistance = 100.0;
            attribute :>> maxResistance = 10000.0;
        }
        
        part :>> rx {
            attribute :>> resistance = 750.0;
        }
        
        part :>> source {
            attribute :>> supplyVoltage = 5.0;
        }
        
        part :>> detector {
            attribute :>> sensitivity = 0.001;
            attribute :>> measuredVoltage = 0.0;
        }
    }
}
