public class SpecialCharsTest {
    // 包含中文、日文、特殊符号的类
    public String testSpecialChars() {
        String chinese = "测试";
        String japanese = "テスト";
        String symbols = "!@#$%^&*()_+-=[]{}|;':\",./<>?";
        return chinese + japanese + symbols;
    }
    
    // 包含表情符号和Unicode字符
    public void testUnicode() {
        String emoji = "😀🎉🚀";
        String unicode = "α β γ δ ε";
    }
}