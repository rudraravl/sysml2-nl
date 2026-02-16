package 'Resistor System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    doc /* 
    This model describes a resistor-based electrical system. A resistor's primary function 
    is to control and limit electrical current flow in a circuit by providing resistance, 
    thereby converting electrical energy into thermal energy according to Ohm's Law.
    
    The system operates by accepting an applied voltage across its terminals and producing 
    a proportional current flow based on its resistance value. As current flows through the 
    resistor, electrical power is dissipated as heat. The system continuously monitors its 
    operating conditions to ensure it remains within safe thermal and power limits.
    
    The resistor transitions through operational states: from idle when no voltage is applied, 
    to active operation when energized, and potentially to an overheated state if thermal 
    limits are exceeded. This state-based behavior ensures safe operation and prevents damage 
    from excessive power dissipation.
    */

    attribute def ResistanceValue :> Real;

    port def ElectricalTerminal {
        attribute voltage : VoltageValue;
        attribute current : ElectricCurrentValue;
    }

    part def Resistor {
        attribute resistance : ResistanceValue;
        attribute powerRating : PowerValue;
        attribute maxTemperature : ThermodynamicTemperatureValue;
        attribute currentTemperature : ThermodynamicTemperatureValue;
        
        port terminal1 : ElectricalTerminal;
        port terminal2 : ElectricalTerminal;
        
        perform action controlCurrent;
        perform action dissipateHeat;
    }

    part def VoltageSource {
        attribute outputVoltage : VoltageValue;
        port positive : ElectricalTerminal;
        port negative : ElectricalTerminal;
    }

    part def Ground {
        port reference : ElectricalTerminal;
    }

    action def CalculateCurrent {
        in appliedVoltage : VoltageValue;
        in resistance : ResistanceValue;
        out resultingCurrent : ElectricCurrentValue;
    }

    action def CalculatePowerDissipation {
        in current : ElectricCurrentValue;
        in voltage : VoltageValue;
        out powerDissipated : PowerValue;
    }

    action def UpdateTemperature {
        in powerDissipated : PowerValue;
        in currentTemp : ThermodynamicTemperatureValue;
        in ambientTemp : ThermodynamicTemperatureValue;
        out newTemperature : ThermodynamicTemperatureValue;
    }

    action def OperateResistor {
        in attribute appliedVoltage : VoltageValue;
        in attribute resistanceValue : ResistanceValue;
        in attribute powerLimit : PowerValue;
        in attribute ambientTemperature : ThermodynamicTemperatureValue;
        out attribute outputCurrent : ElectricCurrentValue;
        out attribute powerDissipated : PowerValue;
        out attribute operatingTemperature : ThermodynamicTemperatureValue;
        
        private attribute temperature := ambientTemperature;
        private attribute overheated : Boolean := false;
        
        first start;
        then merge operationLoop;
        
        then action calculateCurrent : CalculateCurrent {
            in appliedVoltage = OperateResistor::appliedVoltage;
            in resistance = resistanceValue;
            out resultingCurrent;
        }
        
        then assign outputCurrent := calculateCurrent.resultingCurrent;
        
        then action calculatePower : CalculatePowerDissipation {
            in current = calculateCurrent.resultingCurrent;
            in voltage = appliedVoltage;
            out powerDissipated;
        }
        
        then assign powerDissipated := calculatePower.powerDissipated;
        
        then action updateTemp : UpdateTemperature {
            in powerDissipated = calculatePower.powerDissipated;
            in currentTemp = temperature;
            in ambientTemp = ambientTemperature;
            out newTemperature;
        }
        
        then assign temperature := updateTemp.newTemperature;
        then assign operatingTemperature := temperature;
        
        then decide;
            if calculatePower.powerDissipated > powerLimit then flagOverheat;
            if calculatePower.powerDissipated <= powerLimit then continueOperation;
        
        action flagOverheat {
            assign overheated := true;
        }
        then done;
        
        action continueOperation {
            assign overheated := false;
        }
        then operationLoop;
    }

    attribute def VoltageAppliedSignal {
        attribute value : VoltageValue;
    }

    attribute def VoltageRemovedSignal;

    state def ResistorOperationalStates {
        in resistor : Resistor;
        
        entry; then idle;
        
        state idle {
            doc /* Resistor is not conducting current */
        }
        
        transition idle_to_conducting
            first idle
            accept voltageApplied : VoltageAppliedSignal
            then conducting;
        
        state conducting {
            doc /* Resistor is actively limiting current and dissipating power */
            entry; then normalOperation;
            
            state normalOperation {
                doc /* Operating within safe thermal limits */
            }
            
            transition normal_to_heating
                first normalOperation
                if resistor.currentTemperature > resistor.maxTemperature * 0.8
                then heating;
            
            state heating {
                doc /* Temperature rising but still within limits */
            }
            
            transition heating_to_overheated
                first heating
                if resistor.currentTemperature >= resistor.maxTemperature
                then overheated;
            
            transition heating_to_normal
                first heating
                if resistor.currentTemperature < resistor.maxTemperature * 0.7
                then normalOperation;
        }
        
        state overheated {
            doc /* Resistor has exceeded maximum temperature */
        }
        
        transition overheated_to_conducting
            first overheated
            if resistor.currentTemperature < resistor.maxTemperature * 0.9
            then conducting;
        
        transition conducting_to_idle
            first conducting
            accept voltageRemoved : VoltageRemovedSignal
            then idle;
    }

    requirement def ResistorCurrentLimitRequirement {
        doc /* The resistor shall limit current flow according to Ohm's Law: I = V / R */
        
        subject resistor : Resistor;
        
        require constraint ohmLaw {
            (resistor.terminal1.voltage - resistor.terminal2.voltage) == 
                resistor.terminal1.current * resistor.resistance
        }
    }

    requirement def ResistorPowerDissipationRequirement {
        doc /* The resistor shall dissipate electrical power as thermal energy without 
               exceeding its rated power capacity */
        
        subject resistor : Resistor;
        
        require constraint powerWithinRating {
            resistor.terminal1.current * resistor.terminal1.current * 
                resistor.resistance <= resistor.powerRating
        }
    }

    requirement def ResistorThermalRequirement {
        doc /* The resistor shall maintain its operating temperature below the maximum 
               rated temperature to prevent damage */
        
        subject resistor : Resistor;
        
        require constraint temperatureWithinLimit {
            resistor.currentTemperature <= resistor.maxTemperature
        }
    }

    requirement <'RES-SYS-001'> primaryResistorFunction {
        doc /* 
        The resistor system shall control electrical current flow by providing opposition 
        to current according to its resistance value, thereby converting electrical energy 
        into thermal energy. The system shall operate safely within specified power and 
        thermal limits while maintaining predictable current-voltage relationships defined 
        by Ohm's Law.
        */
        
        subject resistorSystem : Resistor;
        
        assume constraint validResistance {
            resistorSystem.resistance > 0.0
        }
        
        assume constraint validPowerRating {
            resistorSystem.powerRating > 0.0
        }
        
        assume constraint validTemperatureRating {
            resistorSystem.maxTemperature > 273.15
        }
        
        require currentLimit : ResistorCurrentLimitRequirement {
            subject resistor = resistorSystem;
        }
        
        require powerDissipation : ResistorPowerDissipationRequirement {
            subject resistor = resistorSystem;
        }
        
        require thermalLimit : ResistorThermalRequirement {
            subject resistor = resistorSystem;
        }
    }

    part resistorCircuit {
        doc /* Complete resistor circuit with voltage source and ground reference */
        
        part source : VoltageSource {
            attribute :>> outputVoltage : VoltageValue = 12.0 [V];
        }
        
        part mainResistor : Resistor {
            attribute :>> resistance : ResistanceValue = 100.0;
            attribute :>> powerRating : PowerValue = 2.0 [W];
            attribute :>> maxTemperature : ThermodynamicTemperatureValue = 398.15 [K];
            attribute :>> currentTemperature : ThermodynamicTemperatureValue = 298.15 [K];
            
            exhibit state behavior : ResistorOperationalStates {
                in resistor = mainResistor;
            }
        }
        
        part ground : Ground;
        
        connect source.positive to mainResistor.terminal1;
        connect mainResistor.terminal2 to source.negative;
        connect source.negative to ground.reference;
        
        perform action operate : OperateResistor {
            in appliedVoltage = source.outputVoltage;
            in resistanceValue = mainResistor.resistance;
            in powerLimit = mainResistor.powerRating;
            in ambientTemperature : ThermodynamicTemperatureValue = 298.15 [K];
            out outputCurrent;
            out powerDissipated;
            out operatingTemperature;
        }
    }
    
    satisfy primaryResistorFunction by resistorCircuit.mainResistor;
}
