package PitotAirspeedMeasurementSystem {
    import ScalarValues::*;
    
    value def PressureValue :> Real {
        doc { "Pressure in Pascals (Pa)" }
    }
    
    value def SpeedValue :> Real {
        doc { "Speed in meters per second (m/s)" }
    }
    
    value def DensityValue :> Real {
        doc { "Density in kilograms per cubic meter (kg/m^3)" }
    }
    
    item def Air {
        attribute totalPressure : PressureValue;
        attribute staticPressure : PressureValue;
    }
    
    item def TotalPressurePayload {
        attribute value : PressureValue;
    }
    
    item def StaticPressurePayload {
        attribute value : PressureValue;
    }
    
    item def DynamicPressurePayload {
        attribute value : PressureValue;
    }
    
    item def AirspeedPayload {
        attribute value : SpeedValue;
    }
    
    port def AirFlowPort {
        in air : Air;
    }
    
    port def TotalPressureOutPort {
        out p : TotalPressurePayload;
    }
    
    port def TotalPressureInPort {
        in p : TotalPressurePayload;
    }
    
    port def StaticPressureOutPort {
        out p : StaticPressurePayload;
    }
    
    port def StaticPressureInPort {
        in p : StaticPressurePayload;
    }
    
    port def DynamicPressureOutPort {
        out p : DynamicPressurePayload;
    }
    
    port def DynamicPressureInPort {
        in p : DynamicPressurePayload;
    }
    
    port def AirspeedOutPort {
        out s : AirspeedPayload;
    }
    
    port def AirspeedInPort {
        in s : AirspeedPayload;
    }
    
    port def PilotDisplayPort {
        in s : AirspeedPayload;
    }
    
    requirement def ProvideContinuousAirspeed {
        attribute updateRate : String = "continuous";
        doc { "The system shall provide pilots with a continuous and accurate airspeed reading essential for safe flight." }
    }
    
    requirement def MeasureDynamicPressure {
        attribute totalPressure : PressureValue;
        attribute staticPressure : PressureValue;
        attribute dynamicPressure : PressureValue;
        doc { "The system shall measure the difference between total and static pressure to determine dynamic pressure." }
        constraint { dynamicPressure == totalPressure - staticPressure }
    }
    
    requirement def CalculateIndicatedAirspeed {
        attribute dynamicPressure : PressureValue;
        attribute standardAirDensity : DensityValue;
        attribute indicatedAirspeed : SpeedValue;
        doc { "The Air Data Computer shall calculate indicated airspeed using Bernoulli's principle and a standard value for air density." }
        constraint { indicatedAirspeed == sqrt(2 * dynamicPressure / standardAirDensity) }
    }
    
    requirement def DisplayAirspeed {
        attribute displayedAirspeed : SpeedValue;
        doc { "The Airspeed Indicator shall present the calculated airspeed to the pilot." }
    }
    
    part def PitotProbe {
        port airIn : AirFlowPort;
        port totalOut : TotalPressureOutPort;
        port staticOut : StaticPressureOutPort;
        
        state sensing {
            do {
                totalOut.p = TotalPressurePayload(value = airIn.air.totalPressure);
                staticOut.p = StaticPressurePayload(value = airIn.air.staticPressure);
            }
        }
        transition initial -> sensing;
    }
    
    part def PressureSensor {
        port totalIn : TotalPressureInPort;
        port staticIn : StaticPressureInPort;
        port dynamicOut : DynamicPressureOutPort;
        
        state calculating {
            do {
                dynamicOut.p = DynamicPressurePayload(value = totalIn.p.value - staticIn.p.value);
            }
        }
        transition initial -> calculating;
    }
    
    part def AirDataComputer {
        port dynamicIn : DynamicPressureInPort;
        port airspeedOut : AirspeedOutPort;
        
        attribute standardAirDensity : DensityValue = 1.225;
        
        state computing {
            do {
                airspeedOut.s = AirspeedPayload(value = sqrt(2 * dynamicIn.p.value / standardAirDensity));
            }
        }
        transition initial -> computing;
    }
    
    part def AirspeedIndicator {
        port airspeedIn : AirspeedInPort;
        port displayOut : AirspeedOutPort;
        
        state displaying {
            do {
                displayOut.s = airspeedIn.s;
            }
        }
        transition initial -> displaying;
    }
    
    part def Pilot {
        port displayIn : PilotDisplayPort;
        
        state monitoring {
            do {
                // Pilot continuously observes airspeed indicator display
            }
        }
        transition initial -> monitoring;
    }
    
    part def PitotAirspeedMeasurementSystem {
        requirement req1 : ProvideContinuousAirspeed;
        requirement req2 : MeasureDynamicPressure;
        requirement req3 : CalculateIndicatedAirspeed;
        requirement req4 : DisplayAirspeed;
        
        part pitotProbe : PitotProbe {
            satisfy req1;
        }
        
        part pressureSensor : PressureSensor {
            satisfy req2;
        }
        
        part airDataComputer : AirDataComputer {
            satisfy req3;
        }
        
        part airspeedIndicator : AirspeedIndicator {
            satisfy req4;
        }
        
        part pilot : Pilot;
        
        connection totalPressureLink connect pitotProbe.totalOut to pressureSensor.totalIn;
        connection staticPressureLink connect pitotProbe.staticOut to pressureSensor.staticIn;
        connection dynamicPressureLink connect pressureSensor.dynamicOut to airDataComputer.dynamicIn;
        connection airspeedLink connect airDataComputer.airspeedOut to airspeedIndicator.airspeedIn;
        connection displayLink connect airspeedIndicator.displayOut to pilot.displayIn;
    }
}
