package 'Pitot Tube Airspeed Measurement System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    doc /* 
        This model describes a Pitot tube airspeed measurement system used in aircraft.
        The primary function is to measure the velocity of airflow by sensing the difference
        between total (stagnation) pressure and static pressure, then converting this 
        differential pressure into an airspeed indication using Bernoulli's principle.
        The system continuously monitors pressures, computes dynamic pressure, calculates
        airspeed based on air density, and displays the result to the pilot.
    */
    
    attribute def TotalPressure :> ISQ::PressureValue;
    attribute def StaticPressure :> ISQ::PressureValue;
    attribute def DynamicPressure :> ISQ::PressureValue;
    attribute def AirDensity :> ISQ::MassDensityValue;
    attribute def IndicatedAirspeed :> ISQ::SpeedValue;
    attribute def MeasurementCommand;
    attribute def SystemShutdown;
    
    port def TotalPressurePort {
        out totalPressure : TotalPressure;
    }
    
    port def StaticPressurePort {
        out staticPressure : StaticPressure;
    }
    
    port def DynamicPressurePort {
        out dynamicPressure : DynamicPressure;
    }
    
    port def AirspeedPort {
        out airspeed : IndicatedAirspeed;
    }
    
    part def PitotProbe {
        doc /* 
            The Pitot probe is the sensing element that measures total pressure
            at the stagnation point and static pressure from side ports.
        */
        
        port totalPort : TotalPressurePort;
        port staticPort : StaticPressurePort;
        
        attribute measuredTotalPressure : TotalPressure;
        attribute measuredStaticPressure : StaticPressure;
    }
    
    part def PressureSensor {
        doc /* 
            The pressure sensor converts the physical pressure differential
            into an electrical signal representing dynamic pressure.
        */
        
        in port totalInput : TotalPressurePort;
        in port staticInput : StaticPressurePort;
        out port dynamicOutput : DynamicPressurePort;
        
        attribute computedDynamicPressure : DynamicPressure;
    }
    
    part def AirDataComputer {
        doc /* 
            The air data computer calculates indicated airspeed from dynamic
            pressure using the Bernoulli equation: V = sqrt(2 * q / rho)
            where q is dynamic pressure and rho is air density.
        */
        
        in port dynamicInput : DynamicPressurePort;
        out port speedOutput : AirspeedPort;
        
        attribute standardAirDensity : AirDensity;
        attribute calculatedAirspeed : IndicatedAirspeed;
    }
    
    part def AirspeedIndicator {
        doc /* 
            The airspeed indicator displays the computed airspeed to the pilot
            in a human-readable format.
        */
        
        in port speedInput : AirspeedPort;
        
        attribute displayedAirspeed : IndicatedAirspeed;
    }
    
    action def SenseTotalPressure {
        out totalPressure : TotalPressure;
    }
    
    action def SenseStaticPressure {
        out staticPressure : StaticPressure;
    }
    
    action def ComputeDynamicPressure {
        in totalPressure : TotalPressure;
        in staticPressure : StaticPressure;
        out dynamicPressure : DynamicPressure;
    }
    
    action def CalculateAirspeed {
        in dynamicPressure : DynamicPressure;
        in airDensity : AirDensity;
        out airspeed : IndicatedAirspeed;
    }
    
    action def DisplayAirspeed {
        in airspeed : IndicatedAirspeed;
    }
    
    action def MeasureAirspeed {
        in attribute densityValue : AirDensity;
        out attribute airspeedValue : IndicatedAirspeed;
        
        first start;
        then merge continueMeasurement;
        then action senseTotal : SenseTotalPressure {
            out totalPressure : TotalPressure;
        }
        then action senseStatic : SenseStaticPressure {
            out staticPressure : StaticPressure;
        }
        then action computeDynamic : ComputeDynamicPressure {
            in totalPressure = senseTotal.totalPressure;
            in staticPressure = senseStatic.staticPressure;
            out dynamicPressure : DynamicPressure;
        }
        then action calculateSpeed : CalculateAirspeed {
            in dynamicPressure = computeDynamic.dynamicPressure;
            in airDensity = densityValue;
            out airspeed : IndicatedAirspeed;
        }
        then assign airspeedValue := calculateSpeed.airspeed;
        then action displaySpeed : DisplayAirspeed {
            in airspeed = calculateSpeed.airspeed;
        }
        then continueMeasurement;
    }
    
    part pitotSystem {
        doc /* 
            The complete Pitot tube airspeed measurement system integrating
            all components to provide continuous airspeed indication.
        */
        
        attribute operatingDensity : AirDensity;
        attribute currentAirspeed : IndicatedAirspeed;
        
        part probe : PitotProbe;
        part sensor : PressureSensor;
        part computer : AirDataComputer {
            attribute standardAirDensity := 1.225[kg/(m^3)];
        }
        part indicator : AirspeedIndicator;
        
        connect probe.totalPort to sensor.totalInput;
        connect probe.staticPort to sensor.staticInput;
        connect sensor.dynamicOutput to computer.dynamicInput;
        connect computer.speedOutput to indicator.speedInput;
        
        perform action measurementCycle : MeasureAirspeed {
            in densityValue = operatingDensity;
            out airspeedValue = currentAirspeed;
        }
    }
    
    requirement def AccuracyRequirement {
        doc /* 
            The system shall measure airspeed with specified accuracy
            across the operational range.
        */
        
        require constraint accuracyTolerance {
            doc /* Airspeed measurement shall be accurate within ±2 knots. */
        }
    }
    
    requirement def ResponseRequirement {
        doc /* 
            The system shall provide timely airspeed updates to support
            safe flight operations.
        */
        
        require constraint updateRate {
            doc /* Airspeed indication shall update at minimum 10 Hz. */
        }
    }
    
    requirement def OperationalRequirement {
        doc /* 
            The system shall operate reliably across the flight envelope.
        */
        
        require constraint temperatureRange {
            doc /* System shall operate from -55°C to +55°C. */
        }
        
        require constraint altitudeRange {
            doc /* System shall operate from sea level to 50,000 feet. */
        }
    }
    
    requirement systemRequirements {
        subject system = pitotSystem;
        
        assume constraint standardAtmosphere {
            doc /* System calibrated for standard atmospheric conditions. */
        }
        
        requirement accuracyReq : AccuracyRequirement;
        
        requirement responseReq : ResponseRequirement;
        
        requirement operationalReq : OperationalRequirement;
    }
}
