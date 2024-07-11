@isTest
public class MySampleClassTest {
    @isTest
    static void testAddIntegers() {
        Integer a = 5;
        Integer b = 10;
        Integer expectedResult = a + b;
        
        Integer actualResult = MySampleClass.addIntegers(a, b);
        
        System.assertEquals(expectedResult, actualResult, 'The sum of integers is not as expected.');
    }
    
    @isTest
    static void testIsStringEmpty() {
        // Test when the string is empty
        String emptyString = '';
        Boolean isEmpty = MySampleClass.isStringEmpty(emptyString);
        System.assertEquals(true, isEmpty, 'The string should be empty.');
        
        // Test when the string is not empty
        String nonEmptyString = 'Hello, World!';
        isEmpty = MySampleClass.isStringEmpty(nonEmptyString);
        System.assertEquals(false, isEmpty, 'The string should not be empty.');
    }
}