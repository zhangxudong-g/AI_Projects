public class PartialMatchTest {
    private String name;
    private int value;
    
    public String getName() {
        return name;
    }
    
    public void setName(String name) {
        this.name = name;
    }
    
    public int getValue() {
        return value;
    }
    
    public void setValue(int value) {
        this.value = value;
    }
    
    public boolean isValid() {
        return name != null && value > 0;
    }
}