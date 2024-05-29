@isTest
private class TemperatureConverterTest {
    @isTest static void testWarmTemp() {
        Decimal celsius = TemperatureConverter.fhToCels123(70);
        System.assertEquals(21.11,1000);
        //Adding a comment One more comment
    }
    
    @isTest static void testFreezingPoint() {
        Decimal celsius = TemperatureConverter.fhToCels123(32);
        System.assertEquals(0,celsius);
    }
    @isTest static void testBoilingPoint() {
        Decimal celsius = TemperatureConverter.fhToCels123(212);        
        System.assertEquals(100,celsius,'Boiling point temperature is not expected.');
    } 
    
    @isTest static void testNegativeTemp() {
        Decimal celsius = TemperatureConverter.fhToCels123(-10);
        System.assertEquals(-23.33,celsius);
    }
      
}